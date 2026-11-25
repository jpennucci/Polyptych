//
//  MSMainWinController.m
//  MultiScape
//
//  Created by David Zwerdling on 12/20/08.
//  Copyright 2010 Laughing Man Software. All rights reserved.
//  This file is part of MultiScape.
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


#import "MSMainWinController.h"
#import "MSBackgroundWorker.h"
#import "MSDaily.h"

@interface MSMainWinController () {
    NSImage * _baseImage;
    MSBackgroundWorker *_worker;
    NSTextField *_folderField;
    NSButton *_dailyBox;
}

- (void) notifyOfCompletedBackgroundExecution:(NSNotification*)notif;

@end

@implementation MSMainWinController

@synthesize baseImage = _baseImage;

#pragma mark Initialization Methods
- (void)awakeFromNib {
    _worker = [[MSBackgroundWorker alloc] init];
    CGSize sz = [_worker perfectSize];
    [sizeLabel setStringValue:[NSString stringWithFormat:@"%.0f x %.0f", sz.width, sz.height]];
    [infoField setStringValue:@""];  // the nib's placeholder said 0 x 0
    [self addDailyControls];
}

#pragma mark Daily
// Two rows under the drop area: the folder, and Change daily / Change now. Added in code, the nib left as it was.
- (void)addDailyControls {
    NSWindow *w = self.window;
    NSView *content = w.contentView;
    const CGFloat extra = 64;
    content.autoresizesSubviews = NO;  // grow the window, then move what's there up by hand, once
    NSRect wf = w.frame; wf.size.height += extra; wf.origin.y -= extra;
    [w setFrame:wf display:NO];
    for (NSView *v in content.subviews) {
        NSRect f = v.frame; f.origin.y += extra; v.frame = f;
    }
    content.autoresizesSubviews = YES;
    CGFloat width = content.bounds.size.width;

    NSTextField *label = [NSTextField labelWithString:@"Daily from:"];
    label.frame = NSMakeRect(17, 40, 80, 20);
    _folderField = [NSTextField labelWithString:[MSDaily folder] ?: @"No folder chosen"];
    _folderField.frame = NSMakeRect(96, 40, width - 96 - 112, 20);
    _folderField.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _folderField.textColor = [MSDaily folder] ? NSColor.labelColor : NSColor.secondaryLabelColor;
    NSButton *choose = [NSButton buttonWithTitle:@"Choose…" target:self action:@selector(chooseFolder:)];
    choose.frame = NSMakeRect(width - 110, 34, 96, 30);

    _dailyBox = [NSButton checkboxWithTitle:@"Change daily (6:00 and at login)" target:self action:@selector(toggleDaily:)];
    _dailyBox.frame = NSMakeRect(17, 10, width - 140, 20);
    _dailyBox.state = [MSDaily isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    NSButton *now = [NSButton buttonWithTitle:@"Change now" target:self action:@selector(changeNow:)];
    now.frame = NSMakeRect(width - 120, 4, 106, 30);

    for (NSView *v in @[label, _folderField, choose, _dailyBox, now]) {
        v.autoresizingMask = (v == _folderField ? NSViewWidthSizable : (v == choose || v == now ? NSViewMinXMargin : 0)) | NSViewMaxYMargin;
        [content addSubview:v];
    }
}

- (void)chooseFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.prompt = @"Use This Folder";
    panel.message = @"Pictures in this folder (and its folders) are used in turn, one a day.";
    if ([panel runModal] != NSModalResponseOK) return;
    [MSDaily setFolder:panel.URL.path];
    _folderField.stringValue = panel.URL.path;
    _folderField.textColor = NSColor.labelColor;
    if ([MSDaily isEnabled]) [MSDaily setEnabled:YES];  // reload the agent with the new folder
}

- (void)toggleDaily:(id)sender {
    NSString *problem = [MSDaily setEnabled:_dailyBox.state == NSControlStateValueOn];
    if (problem) {
        _dailyBox.state = NSControlStateValueOff;
        [infoField setStringValue:problem];
    } else {
        [infoField setStringValue:[MSDaily isEnabled] ? @"A new wallpaper every day at 6:00, and at login." : @"Daily change off."];
    }
}

- (void)changeNow:(id)sender {
    [infoField setStringValue:@"Changing…"];
    [infoField displayIfNeeded];
    [infoField setStringValue:[[MSDaily changeNow] stringByReplacingOccurrencesOfString:@"\n" withString:@"  ·  "]];
}

#pragma mark Main Execute Methods
- (void)setBaseImage:(NSImage*)imageToSet {
    _baseImage = imageToSet;
    NSLog(@"Input image changed");
    [self executeForImage: imageToSet];
}

- (void)notifyOfCompletedBackgroundExecution:(NSNotification*)notif {
    if([notif object] == _worker) {
        [infoField setStringValue:_worker.procText];
    }
}

- (void)executeForImage:(NSImage*)startImage {
    if (baseImageView.image) {
        _worker.baseImage = startImage;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyOfCompletedBackgroundExecution:)
                                                     name:MSBackgroundWorkerFinishedNotification object:_worker];
        [_worker execute];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MSBackgroundWorkerFinishedNotification object:_worker];
    [NSApp terminate:self];
}

@end
