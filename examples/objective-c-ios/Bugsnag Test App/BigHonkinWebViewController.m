#import <WebKit/WebKit.h>
#import <signal.h>
#import "BigHonkinWebViewController.h"
#import <Bugsnag/Bugsnag.h>

@interface BigHonkinWebViewController ()
@property (nonatomic, strong) UIWebView *webView;
@end

@implementation BigHonkinWebViewController

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
