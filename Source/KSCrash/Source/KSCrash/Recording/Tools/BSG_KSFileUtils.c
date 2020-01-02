//
//  KSFileUtils.c
//
//  Created by Karl Stenerud on 2012-01-28.
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

#include "BSG_KSFileUtils.h"

//#define BSG_KSLogger_LocalLevel TRACE
#include "BSG_KSLogger.h"

#include <errno.h>
#include <string.h>
#include <unistd.h>

#define BUFFER_SIZE 65536

char charBuffer[BUFFER_SIZE];
ssize_t bufferLen = 0;

const char *bsg_ksfulastPathEntry(const char *const path) {
    if (path == NULL) {
        return NULL;
    }

    char *lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

bool bsg_ksfuflushWriteBuffer(const int fd) {
    const char *pos = charBuffer;
    while (bufferLen > 0) {
        ssize_t bytesWritten = write(fd, pos, (size_t)bufferLen);
        if (bytesWritten == -1) {
            BSG_KSLOG_ERROR("Could not write to fd %d: %s", fd,
                            strerror(errno));
            return false;
        }
        bufferLen -= bytesWritten;
        pos += bytesWritten;
    }
    return true;
}

bool bsg_ksfuwriteBytesToFD(const int fd, const char *const bytes,
                            ssize_t length) {

    for (ssize_t k = 0; k < length; k++) {
        if (bufferLen >= BUFFER_SIZE) {
            if (!bsg_ksfuflushWriteBuffer(fd)) {
                return false;
            }
        }
        charBuffer[bufferLen] = bytes[k];
        bufferLen++;
    }
    return true;
}
