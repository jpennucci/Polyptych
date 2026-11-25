//
//  main.m
//  MultiScape
//
//  Created by David Zwerdling on 11/11/10.
//  Copyright 2010 Laughing Man Software. All rights reserved.
//  GPL v3.

#import <Cocoa/Cocoa.h>
#import "MSDaily.h"

int main(int argc, char *argv[])
{
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--daily") == 0) {  // the launch agent: the next picture, then quit, no window
            @autoreleasepool {
                [NSApplication sharedApplication];
                NSLog(@"%@", [MSDaily changeNow]);
            }
            return 0;
        }
    }
    return NSApplicationMain(argc,  (const char **) argv);
}
