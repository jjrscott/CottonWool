//
//  CottonWool.m
// 
//  Started with UncaughtExceptions, but gutted most things apart from the
//  backtrace method.
//
//  John Scott
//  Copyright 2010 jjrscott. All rights reserved (that can be).
//
//  UncaughtExceptions.m
//  UncaughtExceptions
//
//  Created by Matt Gallagher on 2010/05/25.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "CottonWool.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>

#include "sys/types.h"
#include <sys/sysctl.h>
#include <string.h>

struct BreadCrumb {
        char *crumbString;
        char *className;
};

#define BREADCRUMB_COUNT (128)
#define BREADCRUMB_PADDING (35)

static volatile int32_t  currentBreadcrumbIndex;
static struct BreadCrumb * breadcrumbs;
void (*endFunction)(void);
BOOL shouldLogToConsole;

@interface CottonWool (Private)

+ (NSArray *)backtrace: (NSUInteger)start;
+ (NSString *)platform;
+ (void)callHome: (NSString *)message;

@end


void CottonWoolHandleException(NSException *exception) {
        [CottonWool callHome:[NSString stringWithFormat:@"Exception: %@\nUserInfo: %@", exception, [exception userInfo]]];
}

void CottonWoolSignalHandler(NSInteger signal) {
        [CottonWool callHome:[NSString stringWithFormat:@"Signal: %d", signal]];
}


@implementation CottonWool

+(void)initialize
{
        endFunction = NULL;
        shouldLogToConsole = NO;
}


+ (NSArray *)backtrace: (NSUInteger)start {
        void *callstack[128];
        
        NSInteger frames = backtrace(callstack, 128);
        char **strs = backtrace_symbols(callstack, frames);
        
        NSInteger i;
        NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
        for (i = start; i < MIN(start + 10, frames); i++) {
                [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
        }
        free(strs);
        
        return backtrace;
}

+ (NSString *) platform {  
        size_t size;  
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);  
        char *machine = malloc(size);  
        sysctlbyname("hw.machine", machine, &size, NULL, 0);  
        NSString *platform = [NSString stringWithCString:machine encoding:NSASCIIStringEncoding];  
        free(machine);  
        return platform;  
}

+ (void)callHome: (NSString *)message {
        if (endFunction != NULL)
                endFunction();
        // Get the app's name
        NSString *displayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        // Make email subject
        NSString *subject = [NSString stringWithFormat:@"%@ failed, and is very sorry", displayName];
        
        NSMutableString *body = [NSMutableString stringWithCapacity:1000];
        
        [body appendFormat:@"%@ doesn't know what just went wrong and needs to call the developers in so they can work out what went wrong.\n\nThere is no personal information below - what you see has been automatically generated to assist the team to figure things out. Feel free to add a comment yourself, every little helps.\n\n", displayName];
        
        // Useful Info
        [body appendFormat:@"%@\n", message];
        [body appendFormat:@"App version: %@\n", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
        [body appendFormat:@"Model: %@\n", [CottonWool platform]];
        [body appendFormat:@"System version: %@\n", [[UIDevice currentDevice] systemVersion]];
        
        // Insert the breadcrumbs
        [body appendString:@"Breadcrumbs:\n"];
        
        for (NSInteger breadcrumbIndex = MAX(0, currentBreadcrumbIndex - BREADCRUMB_COUNT); breadcrumbIndex < currentBreadcrumbIndex; breadcrumbIndex++) {
                
                if ([NSString stringWithUTF8String:breadcrumbs[breadcrumbIndex].crumbString] != nil) {
                        NSString *classNameText = [NSString stringWithUTF8String:breadcrumbs[breadcrumbIndex % BREADCRUMB_COUNT].className];
                        
                        
                        if ([classNameText length] < BREADCRUMB_PADDING) {
                                classNameText = [classNameText stringByPaddingToLength:BREADCRUMB_PADDING withString:@" " startingAtIndex:0];
                        }
                        
                        [body appendFormat:@"%-3d %@ %@\n", breadcrumbIndex, classNameText, [NSString stringWithUTF8String:breadcrumbs[breadcrumbIndex % BREADCRUMB_COUNT].crumbString]];
                }
        }
        
        NSString *subject_escaped = [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *body_escaped = [body stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        subject_escaped = [subject_escaped stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
        body_escaped = [body_escaped stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:" COTTON_WOOL_EMAIL_ADDRESS @"?subject=%@&body=%@",subject_escaped, body_escaped]]];
        exit(0);
}

+ (void) wrap {
        currentBreadcrumbIndex = 0;
        breadcrumbs = calloc(sizeof(struct BreadCrumb), BREADCRUMB_COUNT);
    
#if !TARGET_IPHONE_SIMULATOR
        NSSetUncaughtExceptionHandler(&CottonWoolHandleException);
        signal(SIGABRT, CottonWoolSignalHandler);
        signal(SIGILL, CottonWoolSignalHandler);
        signal(SIGSEGV, CottonWoolSignalHandler);
        signal(SIGFPE, CottonWoolSignalHandler);
        signal(SIGBUS, CottonWoolSignalHandler);
        signal(SIGPIPE, CottonWoolSignalHandler);
#endif
}

+ (void)crumbWithString: (NSString *)name class:(Class)class {
        int32_t newIndex = OSAtomicIncrement32Barrier(&currentBreadcrumbIndex) - 1;
        
        int32_t index = newIndex % BREADCRUMB_COUNT;
        
        free(breadcrumbs[index].crumbString);
        breadcrumbs[index].crumbString = (char *) malloc(sizeof(char) * ([name length]));
        strcpy(breadcrumbs[index].crumbString, [name UTF8String]);
        
        NSString *className = NSStringFromClass(class);
        
        free(breadcrumbs[index].className);
        breadcrumbs[index].className = (char *) malloc(sizeof(char) * ([className length]));
        strcpy(breadcrumbs[index].className, [className UTF8String]);
        
        if (shouldLogToConsole)
                NSLog(@"%-3d %@ %@\n", newIndex, [NSString stringWithUTF8String:breadcrumbs[index].className], name);
}


+ (void)crumbWithString: (NSString *)name object:(NSObject*)object {
        [self crumbWithString:name class:[object class]];
}

+ (void) sendFeedback: (UIViewController <MFMailComposeViewControllerDelegate>*)viewController {
  NSMutableString *body = [NSMutableString stringWithCapacity:1000];
  
  [body appendFormat:@"\n\n\nApp version: %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
  [body appendFormat:@"\nModel: %@", [CottonWool platform]];
  UIDevice * device = [UIDevice currentDevice];
  
  [body appendFormat:@"\nSystem version: %@", [device systemVersion]];
  
  NSString *displayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
  NSString *subject = [NSString stringWithFormat:@"%@ Feedback", displayName];
  
  if ([MFMailComposeViewController canSendMail])
  {
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = viewController;
    
    [picker setToRecipients:[NSArray arrayWithObject:COTTON_WOOL_EMAIL_ADDRESS]];
    [picker setSubject:subject];
    [picker setMessageBody:body isHTML:NO];
    
    [viewController presentModalViewController:picker animated:YES];
    [picker release];
  }
  else
  {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:" COTTON_WOOL_EMAIL_ADDRESS @"?subject=%@&body=%@",[subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [body stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]];
  }
}

+ (void) setEndFunction:(void (*)())function
{
  endFunction = function;
}

+ (void) setLogToConsole:(BOOL)logToConsole
{
  shouldLogToConsole = logToConsole;
}

@end
