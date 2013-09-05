//
//  BugsnagEvent.h
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BugsnagConfiguration.h"
#import "BugsnagMetaData.h"

// "bit[0] of lr is set to the current value of the Thumb bit in the CPSR.
// The means that the return instruction can automatically return to the correct processor state."
// http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0203h/Cacbacic.html
//
#define ARMV7_IS_THUMB_MASK (0x00000001)
#define ARMV7_ADDRESS_MASK (~ARMV7_IS_THUMB_MASK)
#define ARMV7_THUMB_INSTRUCTION_SIZE 2
#define ARMV7_FULL_INSTRUCTION_SIZE 4

@interface BugsnagEvent : NSObject

- (id) initWithConfiguration:(BugsnagConfiguration *)configuration andMetaData:(BugsnagMetaData*)metaData;

- (void) addSignal:(int) signal;
- (void) addException:(NSException*)exception;

- (NSDictionary *) toDictionary;

- (NSDictionary *) loadedImages;
- (NSArray *) getStackTraceWithException:(NSException*) exception;

@end
