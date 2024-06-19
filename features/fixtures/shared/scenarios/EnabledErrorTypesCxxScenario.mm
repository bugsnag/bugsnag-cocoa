#import "Scenario.h"
#import "Logging.h"

#import <exception>

class disabled_cxx_reporting_kaboom_exception : public std::exception {
    virtual const char *what() const throw();
};

const char *disabled_cxx_reporting_kaboom_exception::what() const throw() {
    return "If this had been a real exception, you would be cursing now.";
}

/**
 * Throw an uncaught C++ exception. This is a difficult case for crash reporters to handle,
 * as it involves the destruction of the data necessary to generate a correct backtrace.
 */
@interface EnabledErrorTypesCxxScenario : Scenario
@end

@implementation EnabledErrorTypesCxxScenario

- (void)configure {
    [super configure];
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.cppExceptions = false;
    errorTypes.ooms = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = false;
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        // std::exception terminates with abort() by default, therefore discard SIGABRT
        return ![@"SIGABRT" isEqualToString:event.errors[0].errorClass];
    }];
}

- (void)run {
    [self crash];
}

- (void)crash {
    [self waitForEventDelivery:^{
        // Notify error so that mazerunner sees something
        [Bugsnag notifyError:[NSError errorWithDomain:@"com.bugsnag" code:833 userInfo:nil]];
    } andThen:^{
        throw new disabled_cxx_reporting_kaboom_exception;
    }];
}

@end
