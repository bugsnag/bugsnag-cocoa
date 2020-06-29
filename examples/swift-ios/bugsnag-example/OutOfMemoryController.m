// Copyright (c) 2016 Bugsnag, Inc. All rights reserved.
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

#import <WebKit/WebKit.h>
#import <signal.h>
#import "OutOfMemoryController.h"
#import <Bugsnag/Bugsnag.h>

@interface OutOfMemoryController ()
@property (nonatomic, strong) UIWebView *webView;
@end

@implementation OutOfMemoryController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.webView loadHTMLString:@"<h2>Loading a lot of JavaScript. Please wait.</h2>"
                                  "<p>You can follow along in Console.app</p>"
                         baseURL:nil];
    [self.view addSubview:self.webView];
}

- (void)didReceiveMemoryWarning {
    NSLog(@"--> Received a low memory warning");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSString *format = @"var b = document.createElement('div'); div.innerHTML = 'Hello item %d'; document.documentElement.appendChild(div);";
    for (int i = 0; i < 3000 * 1024; i++) {
        NSString *item = [NSString stringWithFormat:format, i];
        [self.webView stringByEvaluatingJavaScriptFromString:item];

        if (i % 1000 == 0) {
            NSLog(@"Loaded %d items", i);
        }
    }
}

@end
