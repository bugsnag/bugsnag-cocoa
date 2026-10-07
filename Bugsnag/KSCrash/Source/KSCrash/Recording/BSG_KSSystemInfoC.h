//
//  KSSystemInfoC.h
//
//  Created by Karl Stenerud on 2012-05-08.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

/* C interface to the system information.
 */

#ifndef BSG_KSCrash_KSSystemInfoC_h
#define BSG_KSCrash_KSSystemInfoC_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Get the complete system info dictionary encoded to JSON.
 *
 * @return System info as JSON. Caller is responsible for calling free().
 */
char *bsg_kssysteminfo_toJSON(void);

/** The legacy (dyld image scan based) jailbreak check's latest known result.
 *
 * A single lock-free atomic load: never blocks, allocates, or starts the
 * scan itself, so it is safe to call from a crash handler. The scan is
 * started separately (see bsg_kssysteminfo_prefetchJailbreakStatus() in
 * BSG_KSSystemInfo.h); before it finishes, this returns the best answer
 * known so far, which may still be false if the only positive indicator
 * is the slow fallback scan and it has not completed yet.
 *
 * @return The current jailbreak status.
 */
bool bsg_kssysteminfo_isJailbroken(void);

/** Whether the legacy jailbreak scan has finished (or was never necessary,
 * e.g. because the fast check already found a positive result).
 *
 * Lock-free; never starts or waits for the scan. Useful for diagnostics or
 * callers that want to distinguish "definitely not jailbroken" from
 * "not detected (yet)".
 *
 * @return true once bsg_kssysteminfo_isJailbroken() reflects a final result.
 */
bool bsg_kssysteminfo_isJailbreakDetectionComplete(void);

/** Create a copy of the current process name.
 *
 * @return The process name. Caller is responsible for calling free().
 */
char *bsg_kssysteminfo_copyProcessName(void);

#ifdef __cplusplus
}
#endif

#endif
