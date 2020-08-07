//
//  UserPersistenceScenarios.h
//  iOSTestApp
//
//  Created by Robin Macharg on 24/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Scenario.h"

#ifndef UserPersistenceScenarios_h
#define UserPersistenceScenarios_h

@interface UserPersistencePersistUserScenario : Scenario
@end

@interface UserPersistencePersistUserClientScenario : Scenario
@end

@interface UserPersistenceDontPersistUserScenario : Scenario
@end

@interface UserPersistenceNoUserScenario : Scenario
@end

#endif /* UserPersistenceScenarios_h */
