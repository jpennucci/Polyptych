//
//  MSBackgroundWorker.h
//  MultiScape
//
//  Created by David Zwerdling on 11/11/10.
//  Copyright 2010 Laughing Man Software. All rights reserved.
//  Modified 2026-11-25 by James Pennucci for Polyptych: layouts, dryRun, no Scripting Bridge.
//
//MultiScape is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.

//MultiScape is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.

//You should have received a copy of the GNU General Public License
//along with MultiScape.  If not, see <http://www.gnu.org/licenses/>.

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

typedef NS_ENUM(NSInteger, MSLayout) {  // the order of the Layout menu; saved as a number
    MSLayoutAuto = 0,     // span when 2:1 or wider, else one screen
    MSLayoutSpanFill,     // one picture across every screen, cropped to fill
    MSLayoutSpanFit,      // the whole picture across every screen, a blur around it
    MSLayoutEachFill,     // the same picture on every screen, cropped to fill each
    MSLayoutEachFit,      // the same picture whole on every screen, a blur around it
    MSLayoutOneFill,      // the screen whose shape fits best, filled; a blur on the rest
    MSLayoutOneFit,       // the same screen, the whole picture; a blur around it and on the rest
};

#define MSBackgroundWorkerFinishedNotification @"MSBackgroundWorkerFinishedNotification"

@interface MSBackgroundWorker : NSObject {
    NSImage *__weak baseImage;

    //For creating the folders for output
    NSFileManager *fileManager;

    NSString *procText;
}

@property (weak, readwrite) NSImage *baseImage; 
@property (copy, readwrite) NSString *procText;
@property (assign, readwrite) MSLayout layout;
@property (assign, readwrite) BOOL dryRun;     // make the pictures, leave the wallpaper alone

- (void)execute;

- (CGSize)perfectSize;

@end
