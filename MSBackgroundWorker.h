//
//  MSBackgroundWorker.h
//  MultiScape
//
//  Created by David Zwerdling on 11/11/10.
//  Copyright 2010 Laughing Man Software. All rights reserved.
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

#define MSBackgroundWorkerFinishedNotification @"MSBackgroundWorkerFinishedNotification"

@interface MSBackgroundWorker : NSObject {
    NSImage *__weak baseImage;

    //For creating the folders for output
    NSFileManager *fileManager;

    NSString *procText;
}

@property (weak, readwrite) NSImage *baseImage; 
@property (copy, readwrite) NSString *procText;
@property (assign, readwrite) BOOL dryRun;     // make the pictures, leave the wallpaper alone

- (void)execute;

- (CGSize)perfectSize;

@end
