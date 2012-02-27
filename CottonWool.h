//
//  CottonWool.h
// 
//  Started with UncaughtExceptions, but gutted most things apart from the
//  backtrace method.
//
//  John Scott
//  Copyright 2010 jjrscott. All rights reserved (that can be).
//
//  UncaughtExceptions.h
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

#import <UIKit/UIKit.h>

#import <MessageUI/MessageUI.h>

// Setup macros to run ARC/non ARC specific code
#define CWRelease(OBJ) ;
#else
#define CWRelease(OBJ) [OBJ release];
#endif


#define CWLog(...) ({if (@encode(__typeof__(self)) == @encode(Class)) {[CottonWool crumbWithString:[NSString stringWithFormat:__VA_ARGS__] class:(Class)self];} {[CottonWool crumbWithString:[NSString stringWithFormat:__VA_ARGS__] class:[(NSObject*)self class]];}})


@interface CottonWool : NSObject

+ (void) wrap;
+ (void) crumbWithString: (NSString *)name class: (Class)class;
+ (void) sendFeedback:(UIViewController <MFMailComposeViewControllerDelegate>* )viewController;
+ (void) setEndFunction:(void (*)())function;
+ (void) setLogToConsole:(BOOL)logToConsole;

@end
