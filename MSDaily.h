//  MSDaily.h: a new wallpaper every hour or day from a folder, set by a launch agent running Polyptych --daily.
//  Copyright 2026 James Pennucci. GPL v3 (see LICENSE), as the rest of Polyptych, a fork of MultiScape.

#import <Cocoa/Cocoa.h>
#import "MSBackgroundWorker.h"

typedef NS_ENUM(NSInteger, MSSchedule) { MSScheduleOff = 0, MSScheduleHourly, MSScheduleDaily };  // the Change menu

@interface MSDaily : NSObject

+ (NSString *)folder;                 // nil until one is chosen
+ (void)setFolder:(NSString *)folder;
+ (MSSchedule)schedule;               // Off when the launch agent isn't installed
+ (NSString *)setSchedule:(MSSchedule)schedule;  // installs, changes or removes it; nil, or what went wrong
+ (MSLayout)layout;
+ (void)setLayout:(MSLayout)layout;
+ (NSString *)changeNow;              // the next picture, set now; what happened, in a line or two
+ (NSString *)applyAgain;             // the folder's current picture again (after a layout change), or nil

@end
