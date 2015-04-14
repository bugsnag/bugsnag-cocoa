//
//  ViewController.h
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
- (IBAction)generateException:(id)sender;
- (IBAction)generateSignal:(id)sender;
- (IBAction)delayedException:(id)sender;
- (IBAction)nonFatalException:(id)sender;

@end
