//
//  BSGUtils.m
//  Bugsnag
//
//  Created by Nick Dowell on 18/06/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGUtils.h"

dispatch_queue_t BSGGetFileSystemQueue(void) {
    static dispatch_once_t onceToken;
    static dispatch_queue_t queue;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.bugsnag.filesystem", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}
