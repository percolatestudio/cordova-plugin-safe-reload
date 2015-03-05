#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>


@interface PSSafeReload : CDVPlugin {}


/* Exec API */
- (void)bridgeHealthCheckPassed:(CDVInvokedUrlCommand*)command;
- (void)bridgeHealthCheckFailed:(CDVInvokedUrlCommand*)command;

@end;
