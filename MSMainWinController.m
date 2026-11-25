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
    NSPopUpButton *_layoutMenu;
    NSPopUpButton *_scheduleMenu;
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

#pragma mark Folder, layout and schedule
// Three rows under the drop area: the folder; the layout; how often it changes, and Change now.
// Added in code, the nib left as it was.
- (void)addDailyControls {
    NSWindow *w = self.window;
    NSView *content = w.contentView;
    const CGFloat extra = 100;
    content.autoresizesSubviews = NO;  // grow the window, then move what's there up by hand, once
    NSRect wf = w.frame; wf.size.height += extra; wf.origin.y -= extra;
    [w setFrame:wf display:NO];
    for (NSView *v in content.subviews) {
        NSRect f = v.frame; f.origin.y += extra; v.frame = f;
    }
    content.autoresizesSubviews = YES;
    CGFloat width = content.bounds.size.width;

    NSTextField *folderLabel = [NSTextField labelWithString:@"Folder:"];
    folderLabel.frame = NSMakeRect(17, 76, 64, 20);
    _folderField = [NSTextField labelWithString:[MSDaily folder] ?: @"No folder chosen"];
    _folderField.frame = NSMakeRect(80, 76, width - 80 - 112, 20);
    _folderField.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _folderField.textColor = [MSDaily folder] ? NSColor.labelColor : NSColor.secondaryLabelColor;
    NSButton *choose = [NSButton buttonWithTitle:@"Choose…" target:self action:@selector(chooseFolder:)];
    choose.frame = NSMakeRect(width - 110, 70, 96, 30);

    NSTextField *layoutLabel = [NSTextField labelWithString:@"Layout:"];
    layoutLabel.frame = NSMakeRect(17, 44, 64, 20);
    _layoutMenu = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(76, 39, 260, 28) pullsDown:NO];
    // In MSLayout's order.
    [_layoutMenu addItemsWithTitles:@[@"Auto", @"Span – fill (clips top / bottom)", @"Span – fit (whole picture)", @"Each screen – fill",
                                      @"Each screen – fit", @"One screen – fill", @"One screen – fit"]];
    NSArray *tips = @[@"2:1 or wider spans every screen; narrower goes on the screen whose shape fits best",
                      @"One picture across all screens, as wide as all of them; a regular picture loses its top and bottom, a panorama wider than the screens its sides",
                      @"The whole picture across every screen, nothing cut, a blur around it",
                      @"The same picture on every screen, cropped to fill each",
                      @"The same picture whole on every screen, a blur around it",
                      @"The screen whose shape fits best, filled; a blur on the others",
                      @"The screen whose shape fits best, the whole picture; a blur around it and on the others"];
    for (NSInteger i = 0; i < tips.count; i++) [_layoutMenu itemAtIndex:i].toolTip = tips[i];
    [_layoutMenu selectItemAtIndex:[MSDaily layout]];
    _layoutMenu.target = self; _layoutMenu.action = @selector(layoutChanged:);

    NSTextField *changeLabel = [NSTextField labelWithString:@"Change:"];
    changeLabel.frame = NSMakeRect(17, 12, 64, 20);
    _scheduleMenu = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(76, 7, 260, 28) pullsDown:NO];
    [_scheduleMenu addItemsWithTitles:@[@"Off", @"Every hour", @"Every day at 6:00"]];  // in MSSchedule's order
    [_scheduleMenu selectItemAtIndex:[MSDaily schedule]];
    _scheduleMenu.toolTip = @"Also at login. A Mac asleep at the time changes when it wakes.";
    _scheduleMenu.target = self; _scheduleMenu.action = @selector(scheduleChanged:);
    NSButton *now = [NSButton buttonWithTitle:@"Change now" target:self action:@selector(changeNow:)];
    now.frame = NSMakeRect(width - 120, 6, 106, 30);

    for (NSView *v in @[folderLabel, _folderField, choose, layoutLabel, _layoutMenu, changeLabel, _scheduleMenu, now]) {
        v.autoresizingMask = (v == _folderField ? NSViewWidthSizable : (v == choose || v == now ? NSViewMinXMargin : 0)) | NSViewMaxYMargin;
        [content addSubview:v];
    }
}

- (void)chooseFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.prompt = @"Use This Folder";
    panel.message = @"Pictures in this folder (and its folders) are used in turn.";
    if ([panel runModal] != NSModalResponseOK) return;
    [MSDaily setFolder:panel.URL.path];
    _folderField.stringValue = panel.URL.path;
    _folderField.textColor = NSColor.labelColor;
    MSSchedule s = [MSDaily schedule];
    if (s != MSScheduleOff) [MSDaily setSchedule:s];  // reload the agent with the new folder
}

- (void)layoutChanged:(id)sender {
    [MSDaily setLayout:_layoutMenu.indexOfSelectedItem];
    // Show it straight away: the picture dropped here, else the folder's current one.
    [infoField setStringValue:@"Changing…"];
    [infoField displayIfNeeded];
    if (_baseImage) {
        [self executeForImage:_baseImage];
    } else {
        NSString *done = [MSDaily applyAgain];
        [infoField setStringValue:done ? [done stringByReplacingOccurrencesOfString:@"\n" withString:@"  ·  "] : @""];
    }
}

- (void)scheduleChanged:(id)sender {
    MSSchedule s = _scheduleMenu.indexOfSelectedItem;
    NSString *problem = [MSDaily setSchedule:s];
    if (problem) {
        [_scheduleMenu selectItemAtIndex:MSScheduleOff];
        [infoField setStringValue:problem];
    } else {
        NSArray *said = @[@"Off: it changes only when you drop a picture or click Change now.",
                          @"A new picture every hour, and at login.", @"A new picture every day at 6:00, and at login."];
        [infoField setStringValue:said[s]];
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
        _worker.layout = [MSDaily layout];
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
