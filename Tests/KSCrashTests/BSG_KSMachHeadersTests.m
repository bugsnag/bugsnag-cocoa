//
//  BSG_KSMachHeadersTests.m
//  Tests
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BSG_KSMachHeaders.h"
#import "BSG_Symbolicate.h"
#import <Bugsnag/Bugsnag.h>
#import <XCTest/XCTest.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <mach/mach.h>

@interface BSG_KSMachHeadersTests : XCTestCase
@end

static bool initializationReadersFailedSafely;

static void readDuringInitialization(void) {
    __block atomic_bool safe = true;
    dispatch_apply(16, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(__unused size_t index) {
        BSG_Mach_Header_Info image;
        uint32_t count = 99;
        if (bsg_mach_headers_get_images(&count) != NULL || count != 0 ||
            bsg_mach_headers_get_main_image(&image) ||
            bsg_mach_headers_get_self_image(&image) ||
            bsg_mach_headers_get_dyld_image(&image) ||
            bsg_mach_headers_image_at_address((uintptr_t)&readDuringInitialization, &image)) {
            atomic_store(&safe, false);
        }
    });
    initializationReadersFailedSafely = atomic_load(&safe);
}

@implementation BSG_KSMachHeadersTests

- (void)setUp {
    [super setUp];
    bsg_test_support_mach_headers_reset();
    bsg_mach_headers_initialize();
}

- (void)tearDown {
    bsg_test_support_mach_headers_reset();
    [super tearDown];
}

- (void)testInitializationDoesNotEnumerateEveryImage {
    uint32_t imageCount = 0;
    XCTAssertNotEqual(bsg_mach_headers_get_images(&imageCount), NULL);
    XCTAssertGreaterThan(imageCount, 0u);

    // Initialization caches only the main executable, dyld, and Bugsnag.
    uint32_t cachedImageCount =
        bsg_test_support_mach_headers_cached_image_count();
    XCTAssertLessThanOrEqual(cachedImageCount, 3u);
    if (imageCount > 3) {
        XCTAssertLessThan(cachedImageCount, imageCount);
    }
}

- (void)testGetImagesReturnsDyldsLiveImageArray {
    uint32_t imageCount = 0;
    const BSG_Dyld_Image_Info *images =
        bsg_mach_headers_get_images(&imageCount);

    XCTAssertNotEqual(images, NULL);
    XCTAssertGreaterThan(imageCount, 0u);

    const struct mach_header *mainHeader = _dyld_get_image_header(0);
    BOOL foundMainImage = NO;
    for (uint32_t i = 0; i < imageCount; i++) {
        if (images[i].imageLoadAddress == mainHeader) {
            foundMainImage = YES;
            break;
        }
    }
    XCTAssertTrue(foundMainImage);
}

- (void)testGetImageNameNULL {
    XCTAssertFalse(bsg_mach_headers_image_named(NULL, false, NULL));
}

- (void)testUnavailableDyldArrayReturnsZeroCount {
    struct dyld_all_image_infos info = {0};
    info.infoArrayCount = 17;
    bsg_test_support_mach_headers_set_dyld_info(&info);
    uint32_t count = 99;
    XCTAssertEqual(bsg_mach_headers_get_images(&count), NULL);
    XCTAssertEqual(count, 0u);
    BSG_Mach_Header_Info image;
    XCTAssertFalse(bsg_mach_headers_image_at_address(UINTPTR_MAX, &image));
    bsg_test_support_mach_headers_reset();
}

- (void)testGetImagesAcceptsStableArrayWithOptionalCount {
    BSG_Dyld_Image_Info entries[2];
    memset(entries, 0, sizeof(entries));
    struct dyld_all_image_infos info = {0};
    info.infoArray = entries;
    info.infoArrayCount = 2;
    // A non-zero, unchanging timestamp: proves the new stability check
    // accepts a genuinely stable read, not just the zero-initialized
    // default this fixture would otherwise leave untested.
    info.infoArrayChangeTimestamp = 0x1234;
    bsg_test_support_mach_headers_set_dyld_info(&info);
    uint32_t count = 99;
    XCTAssertEqual(bsg_mach_headers_get_images(&count), (const BSG_Dyld_Image_Info *)entries);
    XCTAssertEqual(count, 2u);
    XCTAssertEqual(bsg_mach_headers_get_images(NULL), (const BSG_Dyld_Image_Info *)entries);
    bsg_test_support_mach_headers_reset();
}

// dyld documents infoArray as transiently NULL while it is being changed.
// This fixture holds it NULL forever (not just transiently), which is the
// worst case for the bounded-retry loop in get_images(): every one of its
// BSG_GET_IMAGES_MAX_ATTEMPTS attempts fails the same way. This proves that
// is still bounded. Recovery from a *transient* change is covered
// deterministically by the testGetImages...Retry... tests below.
- (void)testPersistentlyUnstableDyldArrayGivesUpBoundedly {
    struct dyld_all_image_infos info = {0};
    info.infoArray = NULL;
    info.infoArrayCount = 17;
    info.infoArrayChangeTimestamp = 0x1234;
    bsg_test_support_mach_headers_set_dyld_info(&info);
    uint32_t count = 99;
    NSDate *start = [NSDate date];
    XCTAssertEqual(bsg_mach_headers_get_images(&count), NULL);
    XCTAssertEqual(count, 0u);
    // Generous upper bound: this only guards against an unbounded loop, not
    // a performance target.
    XCTAssertLessThan([[NSDate date] timeIntervalSinceDate:start], 1.0);
    bsg_test_support_mach_headers_reset();
}

// MARK: - get_images() retry, driven deterministically by the test hook
//
// The hook runs at the two points a real concurrent dyld update could land
// (see bsg_test_support_mach_headers_set_get_images_hook), so each scenario
// below scripts exactly what dyld would do between attempts -- no threads,
// no sleeps, no timing.

static struct dyld_all_image_infos *retryInfo;
static BSG_Dyld_Image_Info *retryEntriesA, *retryEntriesB;
static int retryStage0Calls;
static void (*retryScript)(int attempt, int stage);

static void retryHook(int attempt, int stage) {
    if (stage == 0) retryStage0Calls++;
    retryScript(attempt, stage);
}

// dyld publishes a NULL array for the first two attempts, then a good one.
static void scriptNullThenRecovers(int attempt, int stage) {
    if (stage == 0) retryInfo->infoArray = attempt < 2 ? NULL : retryEntriesA;
}

// An update lands mid-read on attempt 0: array and count both change and the
// timestamp advances. Later attempts see the new, stable state.
static void scriptUpdateLandsMidRead(int attempt, int stage) {
    if (stage == 1 && attempt == 0) {
        retryInfo->infoArray = retryEntriesB;
        retryInfo->infoArrayCount = 3;
        retryInfo->infoArrayChangeTimestamp++;
    }
}

// Every attempt but the last is interrupted by an update.
static void scriptStableOnlyOnLastAttempt(int attempt, int stage) {
    if (stage == 1 && attempt < BSG_GET_IMAGES_MAX_ATTEMPTS - 1) {
        retryInfo->infoArrayChangeTimestamp++;
    }
}

// Every attempt is interrupted: dyld never settles.
static void scriptNeverSettles(__unused int attempt, int stage) {
    if (stage == 1) retryInfo->infoArrayChangeTimestamp++;
}

- (void)runRetryScenario:(void (*)(int, int))script
                 initial:(struct dyld_all_image_infos *)info
                  result:(const BSG_Dyld_Image_Info **)result
                   count:(uint32_t *)count {
    retryInfo = info;
    retryStage0Calls = 0;
    retryScript = script;
    bsg_test_support_mach_headers_set_dyld_info(info);
    bsg_test_support_mach_headers_set_get_images_hook(retryHook);
    *count = 99;
    *result = bsg_mach_headers_get_images(count);
    bsg_test_support_mach_headers_reset(); // Also removes the hook.
}

- (void)testGetImagesRetryRecoversFromTransientlyNullArray {
    BSG_Dyld_Image_Info a[2] = {{0}}, b[3] = {{0}};
    retryEntriesA = a; retryEntriesB = b;
    struct dyld_all_image_infos info = {0};
    info.infoArrayCount = 2;
    info.infoArrayChangeTimestamp = 0x1234;
    const BSG_Dyld_Image_Info *result; uint32_t count;
    [self runRetryScenario:scriptNullThenRecovers initial:&info result:&result count:&count];
    XCTAssertEqual(result, (const BSG_Dyld_Image_Info *)a);
    XCTAssertEqual(count, 2u);
    XCTAssertEqual(retryStage0Calls, 3, @"Two failed attempts, then success");
}

- (void)testGetImagesRetryRejectsReadInterruptedByUpdate {
    BSG_Dyld_Image_Info a[2] = {{0}}, b[3] = {{0}};
    retryEntriesA = a; retryEntriesB = b;
    struct dyld_all_image_infos info = {0};
    info.infoArray = a;
    info.infoArrayCount = 2;
    info.infoArrayChangeTimestamp = 0x1234;
    const BSG_Dyld_Image_Info *result; uint32_t count;
    [self runRetryScenario:scriptUpdateLandsMidRead initial:&info result:&result count:&count];
    // Attempt 0 read (a, 2) but the timestamp moved, so it must be discarded.
    // Never a torn pair such as (a, 3) or (b, 2).
    XCTAssertEqual(result, (const BSG_Dyld_Image_Info *)b);
    XCTAssertEqual(count, 3u);
    XCTAssertEqual(retryStage0Calls, 2);
}

- (void)testGetImagesRetrySucceedsOnFinalAllowedAttempt {
    BSG_Dyld_Image_Info a[2] = {{0}}, b[3] = {{0}};
    retryEntriesA = a; retryEntriesB = b;
    struct dyld_all_image_infos info = {0};
    info.infoArray = a;
    info.infoArrayCount = 2;
    info.infoArrayChangeTimestamp = 0x1234;
    const BSG_Dyld_Image_Info *result; uint32_t count;
    [self runRetryScenario:scriptStableOnlyOnLastAttempt initial:&info result:&result count:&count];
    XCTAssertEqual(result, (const BSG_Dyld_Image_Info *)a);
    XCTAssertEqual(count, 2u);
    XCTAssertEqual(retryStage0Calls, BSG_GET_IMAGES_MAX_ATTEMPTS);
}

- (void)testGetImagesRetryGivesUpExactlyAtTheLimitWhenDyldNeverSettles {
    BSG_Dyld_Image_Info a[2] = {{0}}, b[3] = {{0}};
    retryEntriesA = a; retryEntriesB = b;
    struct dyld_all_image_infos info = {0};
    info.infoArray = a;
    info.infoArrayCount = 2;
    info.infoArrayChangeTimestamp = 0x1234;
    const BSG_Dyld_Image_Info *result; uint32_t count;
    [self runRetryScenario:scriptNeverSettles initial:&info result:&result count:&count];
    XCTAssertEqual(result, NULL);
    XCTAssertEqual(count, 0u);
    XCTAssertEqual(retryStage0Calls, BSG_GET_IMAGES_MAX_ATTEMPTS, @"Bounded, not unlimited");
}

- (void)testUnreadableDyldInfoReturnsZeroCount {
    vm_address_t address = 0;
    kern_return_t result = vm_allocate(mach_task_self(), &address,
                                       vm_page_size, VM_FLAGS_ANYWHERE);
    XCTAssertEqual(result, KERN_SUCCESS);
    if (result != KERN_SUCCESS) return;
    bsg_test_support_mach_headers_set_dyld_info((const void *)address);
    result = vm_protect(mach_task_self(), address, vm_page_size, false, VM_PROT_NONE);
    XCTAssertEqual(result, KERN_SUCCESS);
    if (result == KERN_SUCCESS) {
        uint32_t count = 99;
        XCTAssertEqual(bsg_mach_headers_get_images(&count), NULL);
        XCTAssertEqual(count, 0u);
        XCTAssertEqual(bsg_mach_headers_get_images(NULL), NULL);
    }
    bsg_test_support_mach_headers_reset();
    XCTAssertEqual(vm_deallocate(mach_task_self(), address, vm_page_size), KERN_SUCCESS);
}

- (void)testReadersDoNotObservePartialInitialization {
    bsg_test_support_mach_headers_reset();
    initializationReadersFailedSafely = false;
    bsg_test_support_mach_headers_set_initialization_hook(readDuringInitialization);
    bsg_mach_headers_initialize();
    XCTAssertTrue(initializationReadersFailedSafely);
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_main_image(&image));
    XCTAssertTrue(bsg_mach_headers_get_self_image(&image));
}

- (void)testAllLoadedSharedCacheImagesResolve {
    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    // On hosts with more than 64 shared-cache images this also covers the
    // full-cache fallback. Do not require a particular OS image count.
    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header *header = images[i].imageLoadAddress;
        if (header == NULL || !(header->flags & MH_DYLIB_IN_CACHE)) {
            continue;
        }
        BSG_Mach_Header_Info image;
        XCTAssertTrue(bsg_mach_headers_image_at_address((uintptr_t)header, &image));
        XCTAssertEqual(image.header, header);
    }
}

- (void)testGetSelfImage {
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_self_image(&image));
    XCTAssertEqualObjects(@(image.name),
                          @(class_getImageName([Bugsnag class])));
}

- (void)testMainImage {
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_main_image(&image));
    XCTAssertEqualObjects(@(image.name), NSBundle.mainBundle.executablePath);
    XCTAssertEqual(image.header->filetype, MH_EXECUTE);
}

- (void)testDyldImage {
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_get_dyld_image(&image));
    XCTAssertNotEqual(image.header, NULL);
    XCTAssertNotEqual(image.name, NULL);
}

- (void)testImageNamed {
    BSG_Mach_Header_Info mainImage;
    XCTAssertTrue(bsg_mach_headers_get_main_image(&mainImage));

    BSG_Mach_Header_Info foundImage;
    XCTAssertTrue(
        bsg_mach_headers_image_named(mainImage.name, true, &foundImage));
    XCTAssertEqual(foundImage.header, mainImage.header);
}

- (void)testImageNameScanAcrossBatchBoundaries {
    enum { imageCount = 130 };
    BSG_Mach_Header_Info mainImage;
    XCTAssertTrue(bsg_mach_headers_get_main_image(&mainImage));
    NSMutableData *data = [NSMutableData dataWithLength:imageCount * sizeof(struct dyld_image_info)];
    struct dyld_image_info *entries = data.mutableBytes;
    for (unsigned i = 0; i < imageCount; i++) {
        entries[i].imageLoadAddress = mainImage.header;
        entries[i].imageFilePath = "/test/ordinary.dylib";
    }
    struct dyld_all_image_infos info = {0};
    info.infoArray = entries;
    info.infoArrayCount = imageCount;
    bsg_test_support_mach_headers_set_dyld_info(&info);
    XCTAssertFalse(bsg_mach_headers_image_named("MobileSubstrate", false, NULL));
    const unsigned positions[] = {0, 63, 64, 127, 128, 129};
    const char *path = "/test/MobileSubstrate.dylib";
    for (unsigned i = 0; i < sizeof(positions) / sizeof(positions[0]); i++) {
        entries[positions[i]].imageFilePath = path;
        XCTAssertTrue(bsg_mach_headers_image_named("MobileSubstrate", false, NULL));
        XCTAssertFalse(bsg_mach_headers_image_named("MobileSubstrate", true, NULL));
        BSG_Mach_Header_Info image;
        BOOL found = bsg_mach_headers_image_named(path, true, &image);
        XCTAssertTrue(found);
        if (found) {
            XCTAssertEqual(image.header, mainImage.header);
            XCTAssertEqualObjects(@(image.name), @(path));
        }
        entries[positions[i]].imageFilePath = "/test/ordinary.dylib";
    }
    bsg_test_support_mach_headers_reset();
    bsg_mach_headers_initialize();
}

- (void)testImageAtAddress {
    for (NSNumber *number in NSThread.callStackReturnAddresses) {
        uintptr_t address = number.unsignedIntegerValue;
        BSG_Mach_Header_Info image;
        struct dl_info dlinfo = {0};
        if (dladdr((const void *)address, &dlinfo) != 0) {
            XCTAssertTrue(bsg_mach_headers_image_at_address(address, &image));
            XCTAssertEqual(image.header, dlinfo.dli_fbase);
            XCTAssertEqual(image.imageVmAddr + image.slide,
                           (uint64_t)dlinfo.dli_fbase);
            NSString *imagePath =
                [@(image.name) stringByResolvingSymlinksInPath];
            NSString *dladdrPath =
                [@(dlinfo.dli_fname) stringByResolvingSymlinksInPath];
            XCTAssertEqualObjects(imagePath, dladdrPath);
        }
    }
}

- (void)testImageLookupDoesNotGrowStartupCache {
    uint32_t countBefore = bsg_test_support_mach_headers_cached_image_count();
    uintptr_t address = (uintptr_t)class_getMethodImplementation(
        [NSObject class], @selector(description));
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_image_at_address(address, &image));
    XCTAssertEqual(bsg_test_support_mach_headers_cached_image_count(),
                   countBefore);
}

- (void)testConcurrentImageLookups {
    uintptr_t address = (uintptr_t)class_getMethodImplementation(
        [NSObject class], @selector(description));
    __block atomic_bool allLookupsSucceeded = true;
    dispatch_apply(64, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(__unused size_t index) {
                     BSG_Mach_Header_Info image;
                     if (!bsg_mach_headers_image_at_address(address, &image)) {
                         atomic_store(&allLookupsSucceeded, false);
                     }
                   });
    XCTAssertTrue(atomic_load(&allLookupsSucceeded));
}

- (void)testInvalidAddressesDoNotMatchAnImage {
    BSG_Mach_Header_Info image;
    XCTAssertFalse(bsg_mach_headers_image_at_address(0, &image));
    XCTAssertFalse(bsg_mach_headers_image_at_address(0x1000, &image));
    XCTAssertFalse(bsg_mach_headers_image_at_address(UINTPTR_MAX, &image));
}

- (void)testImageMetadataSurvivesUnmapping {
    vm_address_t address = 0;
    XCTAssertEqual(vm_allocate(mach_task_self(), &address, vm_page_size, VM_FLAGS_ANYWHERE), KERN_SUCCESS);
    if (!address) return;
    struct mach_header_64 *header = (void *)address;
    header->magic = MH_MAGIC_64;
    header->ncmds = 2;
    header->sizeofcmds = sizeof(struct segment_command_64) + sizeof(struct uuid_command);
    struct segment_command_64 *segment = (void *)(header + 1);
    segment->cmd = LC_SEGMENT_64;
    segment->cmdsize = sizeof(*segment);
    strcpy(segment->segname, SEG_TEXT);
    segment->vmsize = vm_page_size;
    struct uuid_command *uuid = (void *)(segment + 1);
    uuid->cmd = LC_UUID;
    uuid->cmdsize = sizeof(*uuid);
    memset(uuid->uuid, 0x42, sizeof(uuid->uuid));
    char *path = (void *)(uuid + 1);
    strcpy(path, "/test/unloadable.dylib");
    BSG_Mach_Header_Info image;
    BOOL found = bsg_mach_headers_image_for_header((void *)header, path, &image);
    XCTAssertTrue(found);
    BSG_Mach_Header_Info copy;
    if (found) bsg_mach_headers_copy_image(&copy, &image);
    XCTAssertEqual(vm_deallocate(mach_task_self(), address, vm_page_size), KERN_SUCCESS);
    if (found) {
        XCTAssertEqualObjects(@(image.name), @"/test/unloadable.dylib");
        XCTAssertEqual(image.uuid[0], 0x42);
        memset(&image, 0, sizeof(image));
        XCTAssertEqualObjects(@(copy.name), @"/test/unloadable.dylib");
        XCTAssertEqual(copy.uuid[15], 0x42);
    }
    XCTAssertFalse(bsg_mach_headers_image_for_header((void *)address, "/test/unloadable.dylib", &image));
    struct bsg_symbolicate_result result;
    bsg_symbolicate(address, &result);
    XCTAssertEqual(result.image_header, NULL);
}

- (void)testUnreadableDyldEntryFailsSafely {
    vm_address_t address = 0;
    XCTAssertEqual(vm_allocate(mach_task_self(), &address, vm_page_size, VM_FLAGS_ANYWHERE), KERN_SUCCESS);
    if (!address) return;
    XCTAssertEqual(vm_deallocate(mach_task_self(), address, vm_page_size), KERN_SUCCESS);
    BSG_Dyld_Image_Info entry;
    XCTAssertFalse(bsg_mach_headers_read_image_entry((void *)address, 0, &entry));
}

#pragma mark - Address-sorted image snapshot

- (void)testSnapshotLookupResolvesEveryLoadedImageConsistently {
    // The first lookup builds the sorted snapshot; later ones are served from
    // it. Both must agree with dyld for every loaded image.
    uint32_t count = _dyld_image_count();
    XCTAssertGreaterThan(count, 0u);
    for (int pass = 0; pass < 2; pass++) {
        for (uint32_t i = 0; i < count; i++) {
            const struct mach_header *header = _dyld_get_image_header(i);
            if (!header) continue;
            BSG_Mach_Header_Info image;
            XCTAssertTrue(bsg_mach_headers_image_at_address((uintptr_t)header + 16, &image),
                          @"image %u (%s), pass %d", i, _dyld_get_image_name(i), pass);
            XCTAssertEqual(image.header, header,
                           @"image %u (%s), pass %d", i, _dyld_get_image_name(i), pass);
        }
    }
}

- (void)testSnapshotRejectsAddressesBetweenImagesDefinitively {
    vm_address_t address = 0;
    XCTAssertEqual(vm_allocate(mach_task_self(), &address, vm_page_size, VM_FLAGS_ANYWHERE), KERN_SUCCESS);
    if (!address) return;
    XCTAssertEqual(vm_deallocate(mach_task_self(), address, vm_page_size), KERN_SUCCESS);
    BSG_Mach_Header_Info image;
    for (int i = 0; i < 3; i++) {
        XCTAssertFalse(bsg_mach_headers_image_at_address((uintptr_t)address, &image));
    }
}

- (void)testSnapshotIncludesImagesLoadedAfterItWasBuilt {
    // Build the snapshot first, then load an image that is not yet loaded.
    uintptr_t address = (uintptr_t)class_getMethodImplementation([NSObject class], @selector(description));
    BSG_Mach_Header_Info image;
    XCTAssertTrue(bsg_mach_headers_image_at_address(address, &image));

    static const struct { const char *path; const char *symbol; } candidates[] = {
        {"/usr/lib/libbz2.dylib", "BZ2_bzlibVersion"},
        {"/usr/lib/libcompression.dylib", "compression_encode_buffer"},
        {"/usr/lib/libxml2.dylib", "xmlCleanupParser"},
        {"/usr/lib/libsqlite3.dylib", "sqlite3_libversion"},
        {"/usr/lib/libexpat.dylib", "XML_ParserCreate"},
    };
    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        if (dlopen(candidates[i].path, RTLD_NOLOAD)) continue; // already loaded
        void *handle = dlopen(candidates[i].path, RTLD_NOW);
        if (!handle) continue;
        void *symbol = dlsym(handle, candidates[i].symbol);
        struct dl_info info = {0};
        if (symbol && dladdr(symbol, &info)) {
            BSG_Mach_Header_Info loaded;
            XCTAssertTrue(bsg_mach_headers_image_at_address((uintptr_t)symbol, &loaded));
            XCTAssertEqual(loaded.header, info.dli_fbase);
        }
        dlclose(handle);
        return;
    }
    // Every candidate was already loaded or unavailable on this host.
}

- (void)testSymbolicatingWithAKnownImageMatchesFullSymbolication {
    // bsg_symbolicate_with_image() skips re-resolving the image and re-verifying
    // it for each frame; its result must match bsg_symbolicate().
    uintptr_t addresses[] = {
        (uintptr_t)class_getMethodImplementation([NSObject class], @selector(description)),
        (uintptr_t)class_getMethodImplementation([self class], _cmd),
        (uintptr_t)dlsym(RTLD_MAIN_ONLY, "main"),
        (uintptr_t)&dlopen,
    };
    for (size_t i = 0; i < sizeof(addresses) / sizeof(addresses[0]); i++) {
        if (!addresses[i]) continue;
        BSG_Mach_Header_Info image;
        if (!bsg_mach_headers_image_at_address(addresses[i], &image)) continue;
        struct bsg_symbolicate_result full, known;
        bsg_symbolicate(addresses[i], &full);
        bsg_symbolicate_with_image(addresses[i], &image, &known);
        XCTAssertEqual(known.image_header, full.image_header, @"address %zu", i);
        XCTAssertEqual(known.function_address, full.function_address, @"address %zu", i);
        if (full.function_name) {
            XCTAssertTrue(known.function_name != NULL, @"address %zu", i);
            if (known.function_name) {
                XCTAssertEqual(strcmp(known.function_name, full.function_name), 0, @"address %zu", i);
            }
        } else {
            XCTAssertTrue(known.function_name == NULL, @"address %zu", i);
        }
    }
}

- (void)testRepeatedSymbolicationIsStable {
    // The crash report reuses earlier results for repeated addresses; make sure
    // symbolicating the same address repeatedly always gives the same answer.
    uintptr_t address = (uintptr_t)class_getMethodImplementation([self class], _cmd);
    struct bsg_symbolicate_result first, again;
    bsg_symbolicate(address, &first);
    XCTAssertTrue(first.image_header != NULL);
    for (int i = 0; i < 5; i++) {
        bsg_symbolicate(address, &again);
        XCTAssertEqual(again.image_header, first.image_header);
        XCTAssertEqual(again.function_address, first.function_address);
        XCTAssertEqual((again.function_name == NULL), (first.function_name == NULL));
    }
}

@end

