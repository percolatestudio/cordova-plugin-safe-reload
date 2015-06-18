#import <Cordova/CDV.h>
#import "PSSafeReload.h"
#import "CDVFile.h"

#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <CFNetwork/CFNetwork.h>

#define SR_HEALTH_CHECK_INTERVAL 1.0 // number of seconds to wait before checking if a reload was successful
#define SR_HEALTH_CHECK_TIMEOUT 10.0 // max number of seconds before we determine there was a failure

@interface PSSafeReload ()

@property (nonatomic, strong) NSTimer *reloadTimer;
@property (nonatomic, strong) NSDate *timerStartedAt;
@property (nonatomic, strong) NSURL *appBundleRootUrl;

@end

@implementation PSSafeReload

- (void)pluginInitialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoad:) name:CDVPageDidLoadNotification object:self.webView];
}

- (void)dealloc
{
    [self cancelTimer];
}

- (void)onReset
{
    NSLog(@"SafeReload onReset");
}

- (void)pageDidLoad:(NSNotification*)notification
{
    NSString *currentUrl = [self.webView.request.URL.absoluteString copy];
    NSLog(@"SafeReload pageDidLoad %@", currentUrl);
    
    if (!self.appBundleRootUrl
        && [currentUrl rangeOfString:@"file://"].location != NSNotFound) {
        self.appBundleRootUrl = [NSURL URLWithString:currentUrl];
    }
    else if ([currentUrl rangeOfString:@"meteor.local"].location != NSNotFound) {
        // start the reload timer if we are loading from our local meteor app
        [self startTimer];
    }
}

- (void)startTimer
{
    [self cancelTimer];
    self.reloadTimer = [NSTimer scheduledTimerWithTimeInterval:SR_HEALTH_CHECK_INTERVAL target:self selector:@selector(onTimerFired:) userInfo:nil repeats:YES];
    self.timerStartedAt = [NSDate date];
}

- (void)cancelTimer
{
    if (self.reloadTimer) {
        [self.reloadTimer invalidate];
        self.reloadTimer = nil;
        self.timerStartedAt = nil;
    }
}

- (void)onTimerFired:(NSTimer *)timer
{
    [self performHealthCheck];
}

- (void)performHealthCheck
{
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:self.timerStartedAt];
    if (elapsedTime > SR_HEALTH_CHECK_TIMEOUT) {
        [self healthCheckFailed];
    }
    else {
        NSString *healthCheckJs =
            @"(function () { \
                if (typeof Package === 'undefined' || \
                    ! Package['percolate:safe-reload'] || \
                    ! Package['percolate:safe-reload'].SafeReload || \
                    ! Package['percolate:safe-reload'].SafeReload.healthy() ) { \
                    return 'failed'; \
                } \
                else { \
                    return 'passed'; \
                } \
            })();";
        [self.commandDelegate evalJs:healthCheckJs];
        NSLog(@"SafeReload healthCheck pending...");
    }
}

- (void)healthCheckPassed
{
    NSLog(@"SafeReload healthCheckPassed");
    [self cancelTimer];
}

- (void)healthCheckFailed
{
    NSLog(@"SafeReload healthCheckFailed");
    NSLog(@"This is likely due to a broken Hot Code Push.");
    [self cancelTimer];
    
    if ([self trashCurrentVersion]) {
        if (self.appBundleRootUrl) {
            NSURLRequest* appReq = [NSURLRequest requestWithURL:self.appBundleRootUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0];
            [self.webView loadRequest:appReq];
        }
        else if (self.webView.canGoBack) {
            [self.webView goBack];
        }
    }
}

- (BOOL)trashCurrentVersion
{
    // taken from CDVFile.m::requestAllPaths
    NSString* libPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
    NSString* meteorAppPath = [libPath stringByAppendingString:@"/NoCloud/meteor"];
    NSString* versionFilePath = [meteorAppPath stringByAppendingPathComponent:@"version"];
    
    NSError *error;
    BOOL success = false;
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    BOOL isDirectory;
    if ([fileMgr fileExistsAtPath:versionFilePath isDirectory:&isDirectory]) {
        NSLog(@"SafeReload Removing cached version at %@", versionFilePath);
        [fileMgr removeItemAtPath:versionFilePath error:&error];
        if (!error) {
            success = true;
        }
        else {
            NSLog(@"SafeReload Error removing file: %@", [error localizedDescription]);
        }
    }
    else {
        NSLog(@"SafeReload No versions to remove at %@, uh oh.", versionFilePath);
    }
    return success;
}

- (void)bridgeHealthCheckPassed:(CDVInvokedUrlCommand*)command
{
    [self healthCheckPassed];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)bridgeHealthCheckFailed:(CDVInvokedUrlCommand*)command
{
    [self healthCheckFailed];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

@end;
