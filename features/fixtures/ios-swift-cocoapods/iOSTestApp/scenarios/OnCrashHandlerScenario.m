//
//  OnCrashHandlerScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "OnCrashHandlerScenario.h"

// Create crash handler
void HandleCrashedThread(const BSG_KSCrashReportWriter *writer) {
    // write primitive values
    writer->beginObject(writer, "custom");
    {
        writer->addStringElement(writer, "strVal", "customStrValue");
        writer->addBooleanElement(writer, "boolVal", true);
        writer->addIntegerElement(writer, "intVal", 5);
        writer->addFloatingPointElement(writer, "doubleVal", 3.1495);
    }
    writer->endContainer(writer);

    writer->beginObject(writer, "complex");
    // write array value
    {
        writer->beginArray(writer, "arrayVal");
        writer->endContainer(writer);
    }
    // write nested object value
    {
        writer->beginObject(writer, "objVal");
        writer->addStringElement(writer, "foo", "bar");
        writer->endContainer(writer);
    }
    writer->endContainer(writer);
}

@implementation OnCrashHandlerScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.onCrashHandler = &HandleCrashedThread;
    [super startBugsnag];
}

- (void)run {
    abort();
}

@end
