//  MSDaily.h: a new wallpaper every day from a folder, set by a launch agent running MultiScape --daily.
//  GPL v3, as the rest of MultiScape.

#import <Cocoa/Cocoa.h>

@interface MSDaily : NSObject

+ (NSString *)folder;                 // nil until one is chosen
+ (void)setFolder:(NSString *)folder;
+ (BOOL)isEnabled;                    // the launch agent is installed
+ (NSString *)setEnabled:(BOOL)on;    // installs or removes it; nil, or what went wrong
+ (NSString *)changeNow;              // the next picture, set now; what happened, in a line or two

@end
