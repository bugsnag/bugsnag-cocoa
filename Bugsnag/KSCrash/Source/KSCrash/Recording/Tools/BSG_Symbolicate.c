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

static uintptr_t linkedit_data(const segment_command_t *segment, uintptr_t slide,
                              uint64_t offset, uint64_t size) {
    if (offset < segment->fileoff || size > segment->filesize ||
        offset - segment->fileoff > segment->filesize - size) return 0;
    uintptr_t base = (uintptr_t)segment->vmaddr + slide;
    uint64_t relative = offset - segment->fileoff;
    if (relative > UINTPTR_MAX - base || size > UINTPTR_MAX - (base + relative)) return 0;
    return base + (uintptr_t)relative;
}

void bsg_symbolicate(uintptr_t address, struct bsg_symbolicate_result *result) {
    memset(result, 0, sizeof(*result));
    BSG_Mach_Header_Info image;
    if (!bsg_mach_headers_image_at_address(address, &image)) return;

    bool permanent = (image.flags & MH_DYLIB_IN_CACHE) != 0;
    struct mach_header header;
    if (!read_data(permanent, (uintptr_t)image.header, &header, sizeof(header))) return;
    uintptr_t command = (uintptr_t)image.header +
        ((header.magic == MH_MAGIC_64 || header.magic == MH_CIGAM_64) ?
         sizeof(struct mach_header_64) : sizeof(struct mach_header));
    if (header.sizeofcmds > UINTPTR_MAX - command) return;
    uintptr_t end = command + header.sizeofcmds;
    segment_command_t linkedit = {0};
    struct symtab_command symtab = {0};
    struct linkedit_data_command starts = {0};
    bool hasLinkedit = false, hasStarts = false, hasSymtab = false;
    for (uint32_t i = 0; i < header.ncmds; i++) {
        struct load_command lc;
        if (command > end || end - command < sizeof(lc) ||
            !read_data(permanent, command, &lc, sizeof(lc)) ||
            lc.cmdsize < sizeof(lc) || lc.cmdsize > end - command) goto invalid;
        if (lc.cmd == LC_SEGMENT_BSG) {
            segment_command_t segment;
            if (lc.cmdsize < sizeof(segment) ||
                !read_data(permanent, command, &segment, sizeof(segment))) goto invalid;
            if (!strncmp(segment.segname, SEG_LINKEDIT, sizeof(segment.segname))) {
                linkedit = segment;
                hasLinkedit = true;
            }
            if (!strncmp(segment.segname, SEG_TEXT, sizeof(segment.segname))) {
                if (segment.nsects > (lc.cmdsize - sizeof(segment)) / sizeof(section_t)) goto invalid;
                for (uint32_t j = 0; j < segment.nsects; j++) {
                    section_t section;
                    if (!read_data(permanent, command + sizeof(segment) + j * sizeof(section),
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
                !read_data(permanent, command, &symtab, sizeof(symtab))) goto invalid;
            hasSymtab = true;
        } else if (lc.cmd == LC_FUNCTION_STARTS) {
            if (lc.cmdsize < sizeof(starts) ||
                !read_data(permanent, command, &starts, sizeof(starts))) goto invalid;
            hasStarts = true;
        }
        command += lc.cmdsize;
    }

    if (!hasLinkedit || !hasStarts) goto metadata;
    uintptr_t data = linkedit_data(&linkedit, (uintptr_t)image.slide, starts.dataoff, starts.datasize);
    if (!data) goto invalid;
    uintptr_t function = (uintptr_t)image.header, decoded = 0, value = 0;
    unsigned shift = 0;
    uint8_t bytes[256];
    size_t buffered = 0;
    for (uint32_t i = 0; i < starts.datasize; i++) {
        if (i % sizeof(bytes) == 0) {
            buffered = starts.datasize - i;
            if (buffered > sizeof(bytes)) buffered = sizeof(bytes);
            if (!read_data(permanent, data + i, bytes, buffered)) goto invalid;
        }
        uint8_t byte = bytes[i % sizeof(bytes)];
        if (shift >= sizeof(uintptr_t) * 8 ||
            (uintptr_t)(byte & 0x7f) > (UINTPTR_MAX >> shift)) goto invalid;
        value |= (uintptr_t)(byte & 0x7f) << shift;
        if (byte & 0x80) { shift += 7; continue; }
        if (!value) break;
        if (value > UINTPTR_MAX - function) goto invalid;
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
    if (!symbols || !strings) goto invalid;
    nlist_t best = {{0}};
    nlist_t entries[64];
    for (uint32_t i = 0; i < symtab.nsyms; ) {
        size_t count = symtab.nsyms - i;
        if (count > 64) count = 64;
        if (!read_data(permanent, symbols + (uintptr_t)i * sizeof(nlist_t),
                       entries, count * sizeof(nlist_t))) goto invalid;
        for (size_t j = 0; j < count; j++) {
            nlist_t candidate = entries[j];
            if (candidate.n_value != decoded - (uintptr_t)image.slide ||
                (candidate.n_type & N_STAB) || candidate.n_un.n_strx >= symtab.strsize ||
                ((best.n_type & N_EXT) && !(candidate.n_type & N_EXT))) continue;
            char first;
            if (!read_data(permanent, strings + candidate.n_un.n_strx, &first, 1)) goto invalid;
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
    if (!permanent) {
        // Reject a disappeared/replaced mapping rather than attaching symbols
        // from a different UUID after address reuse.
        BSG_Mach_Header_Info verify;
        if (!bsg_mach_headers_image_for_header(image.header, image.name, &verify) ||
            (!!image.uuid != !!verify.uuid) ||
            (image.uuid && memcmp(image.uuid, verify.uuid, 16))) goto invalid;
    }
    result->image_header = image.header;
    memcpy(result->image_name_storage, image.nameStorage, sizeof(result->image_name_storage));
    result->image_name = result->image_name_storage;
    return;
invalid:
    memset(result, 0, sizeof(*result));
}
