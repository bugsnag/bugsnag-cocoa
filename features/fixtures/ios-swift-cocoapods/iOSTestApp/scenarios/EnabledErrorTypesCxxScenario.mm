#import "EnabledErrorTypesCxxScenario.h"
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
@implementation EnabledErrorTypesCxxScenario

- (void)startBugsnag {
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    errorTypes.cppExceptions = false;
    self.config.enabledErrorTypes = errorTypes;
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [self crash];
}

- (void)crash __attribute__((noreturn)) {
    throw new disabled_cxx_reporting_kaboom_exception;
}

@end
