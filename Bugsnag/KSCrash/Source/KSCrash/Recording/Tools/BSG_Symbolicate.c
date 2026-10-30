//
//  BSG_Symbolicate.c
//  Bugsnag
//
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#include "BSG_Symbolicate.h"
#include "BSG_KSMachHeaders.h"
#include "BSG_KSImageMemory.h"
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <string.h>

#ifdef __LP64__
#define LC_SEGMENT_BSG LC_SEGMENT_64
typedef struct nlist_64 nlist_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
#else
#define LC_SEGMENT_BSG LC_SEGMENT
typedef struct nlist nlist_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
#endif

// Shared-cache mappings cannot be unloaded. Other images are read through the
// kernel; no dyld lock, allocation, or borrowed Mach-O data survives a read.
static bool read_data(bool permanent, uintptr_t address, void *out, size_t size) {
    if (!address || size > UINTPTR_MAX - address) return false;
    if (permanent) {
        memcpy(out, (const void *)address, size);
        return true;
    }
    return bsg_image_read((const void *)address, out, size);
}

// Load commands are contiguous and small (usually 1-4 KB), but reading each
// one through the kernel costs a syscall, and a report can symbolicate
// thousands of frames. Serve them from a small window refilled in bulk, never
// reading past the end of the load-command area.
typedef struct {
    uintptr_t base;
    size_t length;
    uint8_t bytes[2048];
} command_window;

static bool read_command(bool permanent, command_window *window, uintptr_t limit,
                         uintptr_t address, void *out, size_t size) {
    if (permanent || size > sizeof(window->bytes) || address > limit || size > limit - address) {
        return read_data(permanent, address, out, size);
    }
    if (!(address >= window->base && address - window->base <= window->length &&
          size <= window->length - (address - window->base))) {
        size_t count = limit - address;
        if (count > sizeof(window->bytes)) count = sizeof(window->bytes);
        window->length = 0;
        if (!read_data(false, address, window->bytes, count)) {
            return read_data(false, address, out, size);
        }
        window->base = address;
        window->length = count;
    }
    memcpy(out, window->bytes + (address - window->base), size);
    return true;
}

static uintptr_t linkedit_data(const segment_command_t *segment, uintptr_t slide,
                              uint64_t offset, uint64_t size) {
    if (offset < segment->fileoff || size > segment->filesize ||
        offset - segment->fileoff > segment->filesize - size) return 0;
    uintptr_t base = (uintptr_t)segment->vmaddr + slide;
    uint64_t relative = offset - segment->fileoff;
    if (relative > UINTPTR_MAX - base || size > UINTPTR_MAX - (base + relative)) return 0;
    return base + (uintptr_t)relative;
}

// Shared by both entry points below: everything from here on only needs an
// already-resolved image, not how it was found (a fresh dyld-array scan, or
// an image the caller already knows about from earlier in this report).
static void symbolicate_image(uintptr_t address, const BSG_Mach_Header_Info *imagePtr,
                              struct bsg_symbolicate_result *result, bool verifyImage) {
    BSG_Mach_Header_Info image = *imagePtr;
    bool permanent = (image.flags & MH_DYLIB_IN_CACHE) != 0;
    struct mach_header header;
    if (!read_data(permanent, (uintptr_t)image.header, &header, sizeof(header))) return;
    // The main executable stays mapped for the life of the process, like the
    // shared cache, so its (often large) symbol table can be read directly
    // instead of through thousands of kernel reads.
    if (header.filetype == MH_EXECUTE) permanent = true;
    uintptr_t command = (uintptr_t)image.header +
        ((header.magic == MH_MAGIC_64 || header.magic == MH_CIGAM_64) ?
         sizeof(struct mach_header_64) : sizeof(struct mach_header));
    if (header.sizeofcmds > UINTPTR_MAX - command) return;
    uintptr_t end = command + header.sizeofcmds;
    command_window window;
    window.base = 0;
    window.length = 0;
    segment_command_t linkedit = {0};
    struct symtab_command symtab = {0};
    struct linkedit_data_command starts = {0};
    bool hasLinkedit = false, hasStarts = false, hasSymtab = false;
    for (uint32_t i = 0; i < header.ncmds; i++) {
        struct load_command lc;
        if (command > end || end - command < sizeof(lc) ||
            !read_command(permanent, &window, end, command, &lc, sizeof(lc)) ||
            lc.cmdsize < sizeof(lc) || lc.cmdsize > end - command) goto invalid;
        if (lc.cmd == LC_SEGMENT_BSG) {
            segment_command_t segment;
            if (lc.cmdsize < sizeof(segment) ||
                !read_command(permanent, &window, end, command, &segment, sizeof(segment))) goto invalid;
            if (!strncmp(segment.segname, SEG_LINKEDIT, sizeof(segment.segname))) {
                linkedit = segment;
                hasLinkedit = true;
            }
            if (!strncmp(segment.segname, SEG_TEXT, sizeof(segment.segname))) {
                if (segment.nsects > (lc.cmdsize - sizeof(segment)) / sizeof(section_t)) goto invalid;
                for (uint32_t j = 0; j < segment.nsects; j++) {
                    section_t section;
                    if (!read_command(permanent, &window, end,
                                      command + sizeof(segment) + j * sizeof(section),
                                      &section, sizeof(section))) goto invalid;
                    if (!strncmp(section.sectname, SECT_TEXT, sizeof(section.sectname))) {
                        uintptr_t start = section.addr + (uintptr_t)image.slide;
                        if (address < start || address - start >= section.size) goto metadata;
                        break;
                    }
                }
            }
        } else if (lc.cmd == LC_SYMTAB) {
            if (lc.cmdsize < sizeof(symtab) ||
                !read_command(permanent, &window, end, command, &symtab, sizeof(symtab))) goto invalid;
            hasSymtab = true;
        } else if (lc.cmd == LC_FUNCTION_STARTS) {
            if (lc.cmdsize < sizeof(starts) ||
                !read_command(permanent, &window, end, command, &starts, sizeof(starts))) goto invalid;
            hasStarts = true;
        }
        command += lc.cmdsize;
    }

    // From here on, every failure is specific to reading the symbol table
    // itself (function-starts data, nlist entries, the string table) -- the
    // image's own load-command structure was already walked successfully
    // above, so its identity and address range are already established and
    // trustworthy. A symbol-table read failure here (e.g. a transient
    // unmapping) should only cost us the function name/address, not the
    // frame's already-known image: goto metadata, not goto invalid, so the
    // image verification and copy below still runs and the frame keeps its
    // object_addr/binary-image association even without a symbol name.
    if (!hasLinkedit || !hasStarts) goto metadata;
    uintptr_t data = linkedit_data(&linkedit, (uintptr_t)image.slide, starts.dataoff, starts.datasize);
    if (!data) goto metadata;
    uintptr_t function = (uintptr_t)image.header, decoded = 0, value = 0;
    unsigned shift = 0;
    uint8_t bytes[256];
    size_t buffered = 0;
    for (uint32_t i = 0; i < starts.datasize; i++) {
        if (i % sizeof(bytes) == 0) {
            buffered = starts.datasize - i;
            if (buffered > sizeof(bytes)) buffered = sizeof(bytes);
            if (!read_data(permanent, data + i, bytes, buffered)) goto metadata;
        }
        uint8_t byte = bytes[i % sizeof(bytes)];
        if (shift >= sizeof(uintptr_t) * 8 ||
            (uintptr_t)(byte & 0x7f) > (UINTPTR_MAX >> shift)) goto metadata;
        value |= (uintptr_t)(byte & 0x7f) << shift;
        if (byte & 0x80) { shift += 7; continue; }
        if (!value) break;
        if (value > UINTPTR_MAX - function) goto metadata;
        function += value;
        uintptr_t next = function;
#if defined(__arm__)
        next &= ~(uintptr_t)1; // Thumb instruction tag.
#endif
        if (address < next) break;
        decoded = next;
        value = 0;
        shift = 0;
    }
    result->function_address = decoded;
    if (!decoded || !hasSymtab) goto metadata;
    uintptr_t symbols = linkedit_data(&linkedit, (uintptr_t)image.slide, symtab.symoff,
                                      (uint64_t)symtab.nsyms * sizeof(nlist_t));
    uintptr_t strings = linkedit_data(&linkedit, (uintptr_t)image.slide, symtab.stroff, symtab.strsize);
    if (!symbols || !strings) goto metadata;
    nlist_t best = {{0}};
    nlist_t entries[128];
    for (uint32_t i = 0; i < symtab.nsyms; ) {
        size_t count = symtab.nsyms - i;
        if (count > sizeof(entries) / sizeof(entries[0])) count = sizeof(entries) / sizeof(entries[0]);
        if (!read_data(permanent, symbols + (uintptr_t)i * sizeof(nlist_t),
                       entries, count * sizeof(nlist_t))) goto metadata;
        for (size_t j = 0; j < count; j++) {
            nlist_t candidate = entries[j];
            if (candidate.n_value != decoded - (uintptr_t)image.slide ||
                (candidate.n_type & N_STAB) || candidate.n_un.n_strx >= symtab.strsize ||
                ((best.n_type & N_EXT) && !(candidate.n_type & N_EXT))) continue;
            char first;
            if (!read_data(permanent, strings + candidate.n_un.n_strx, &first, 1)) goto metadata;
            if (first) best = candidate;
        }
        i += (uint32_t)count;
    }
    if (best.n_value) {
        size_t capacity = symtab.strsize - best.n_un.n_strx;
        if (capacity > sizeof(result->function_name_storage)) capacity = sizeof(result->function_name_storage);
        if (bsg_image_read_string((const char *)(strings + best.n_un.n_strx),
                                  result->function_name_storage, capacity)) {
            result->function_name = result->function_name_storage;
            if (result->function_name[0] == '_') result->function_name++;
        }
    }
metadata:
    if (!permanent && verifyImage && !bsg_mach_headers_image_is_current(&image)) {
        // Reject a disappeared/replaced mapping rather than attaching symbols
        // from a different UUID after address reuse.
        BSG_Mach_Header_Info verify;
        if (!bsg_mach_headers_image_for_header(image.header, image.name, &verify) ||
            (!!image.uuid != !!verify.uuid) ||
            (image.uuid && verify.uuid && memcmp(image.uuid, verify.uuid, 16))) goto invalid;
    }
    bsg_mach_headers_copy_image(&result->image, &image);
    result->image_header = result->image.header;
    result->image_name = result->image.name;
    return;
invalid:
    memset(result, 0, sizeof(*result));
}

void bsg_symbolicate(uintptr_t address, struct bsg_symbolicate_result *result) {
    memset(result, 0, sizeof(*result));
    // Never trigger lazy initialisation from a crash-handler call: if the
    // cache never finished initialising (e.g. a prior task_info() failure),
    // bail out instead of running calloc()/_dyld_get_image_header() here.
    if (!bsg_mach_headers_ready()) return;
    BSG_Mach_Header_Info image;
    if (!bsg_mach_headers_image_at_address(address, &image)) return;
    symbolicate_image(address, &image, result, true);
}

void bsg_symbolicate_with_image(uintptr_t address, const BSG_Mach_Header_Info *image,
                                struct bsg_symbolicate_result *result) {
    memset(result, 0, sizeof(*result));
    // Same crash-handler guard as bsg_symbolicate(): the known image was
    // itself only ever produced while the cache was ready, but a defensive,
    // cheap, non-initializing check here costs nothing and keeps both entry
    // points consistent.
    if (!bsg_mach_headers_ready()) return;
    symbolicate_image(address, image, result, false);
}

