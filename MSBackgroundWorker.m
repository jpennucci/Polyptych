//
//  MSBackgroundWorker.m
//  MultiScape
//
//  Created by David Zwerdling on 11/11/10.
//  Copyright 2010 Laughing Man Software. All rights reserved.
//
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

#import "MSBackgroundWorker.h"

// Displays of any size, orientation and resolution: each screen's place comes from the arrangement in
// System Settings > Displays (NSScreen frames, in points, rotation already applied). The picture is scaled
// to cover the whole arrangement, centred, and each screen gets its own rectangle at its own pixel count.

@interface MSBackgroundWorker () {
    NSRect _canvas;       // union of every screen's frame, in points
    CGFloat _maxScale;    // the sharpest screen's pixels per point
    CGSize _perfectSize;  // the picture size that covers the canvas at _maxScale, in pixels
}

- (void)mainThreadCompletionNotification;

@end

@implementation MSBackgroundWorker

@synthesize baseImage;
@synthesize procText;

- (instancetype)init {
    if (self = [super init]) {
        fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (CGSize)perfectSize {
    _canvas = NSZeroRect;
    _maxScale = 1.0;
    for (NSScreen *screen in [NSScreen screens]) {
        _canvas = NSIsEmptyRect(_canvas) ? screen.frame : NSUnionRect(_canvas, screen.frame);
        _maxScale = MAX(_maxScale, screen.backingScaleFactor);
        NSLog(@"screen %@: frame %@, scale %.0f", screen.localizedName, NSStringFromRect(screen.frame), screen.backingScaleFactor);
    }
    _perfectSize = CGSizeMake(ceil(_canvas.size.width * _maxScale), ceil(_canvas.size.height * _maxScale));
    return _perfectSize;
}

- (void)mainThreadCompletionNotification {
    NSNotification *n = [NSNotification notificationWithName:MSBackgroundWorkerFinishedNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

- (void)notifyOfCompletionInMainThread {
    [self performSelectorOnMainThread:@selector(mainThreadCompletionNotification) withObject:nil waitUntilDone:NO];
}

- (void)execute {
    [self perfectSize];  // the arrangement may have changed since the window opened
    CIImage *base = [CIImage imageWithData:[baseImage TIFFRepresentation]];
    CGRect b = [base extent];
    if (CGRectIsEmpty(b) || CGRectIsEmpty(_canvas)) {
        self.procText = @"Couldn't read the picture or the displays.";
        [self notifyOfCompletionInMainThread];
        return;
    }

    // Cover the canvas (no stretching), centred: the overhang is cropped equally from both sides.
    double scale = MAX(_perfectSize.width / b.size.width, _perfectSize.height / b.size.height);
    CIImage *scaled = [self scaleImage:base byFactor:scale];
    CGRect se = [scaled extent];
    CGFloat offX = se.origin.x + (se.size.width - _perfectSize.width) / 2.0;
    CGFloat offY = se.origin.y + (se.size.height - _perfectSize.height) / 2.0;

    NSString *outputDirectory = [self outputDirectory];
    CIContext *ctx = [CIContext contextWithOptions:nil];
    NSMutableArray *lines = [NSMutableArray arrayWithObject:
        [NSString stringWithFormat:@"%.0fx%.0f -(x%.3f)-> %.0fx%.0f", b.size.width, b.size.height, scale,
                                   _perfectSize.width, _perfectSize.height]];
    NSUInteger n = 0;
    for (NSScreen *screen in [NSScreen screens]) {
        NSRect f = screen.frame;
        // This screen's rectangle in the scaled picture (Core Image and Cocoa both count y up from the bottom).
        CGRect r = CGRectMake(offX + (f.origin.x - _canvas.origin.x) * _maxScale,
                              offY + (f.origin.y - _canvas.origin.y) * _maxScale,
                              f.size.width * _maxScale, f.size.height * _maxScale);
        CIImage *piece = [[scaled imageByCroppingToRect:r]
                          imageByApplyingTransform:CGAffineTransformMakeTranslation(-r.origin.x, -r.origin.y)];
        // Down to this screen's own pixels (a 1x screen beside 2x ones).
        CGFloat own = screen.backingScaleFactor / _maxScale;
        size_t pw = (size_t)llround(f.size.width * screen.backingScaleFactor);
        size_t ph = (size_t)llround(f.size.height * screen.backingScaleFactor);
        if (own < 1.0) {
            piece = [self scaleImage:piece byFactor:own];
        }
        CGImageRef cg = [ctx createCGImage:piece fromRect:CGRectMake(0, 0, pw, ph)];
        if (!cg) { [lines addObject:[NSString stringWithFormat:@"%@: couldn't render", screen.localizedName]]; continue; }
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cg];
        CGImageRelease(cg);

        NSString *safeName = [[screen.localizedName componentsSeparatedByCharactersInSet:
                               [[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"_"];
        NSString *file = [NSString stringWithFormat:@"%@/%lu-%@.jpg", outputDirectory, (unsigned long)n++, safeName];
        [self saveImageToFile:file imageRep:rep];

        if (self.dryRun) { [lines addObject:[NSString stringWithFormat:@"%@: %zux%zu made", screen.localizedName, pw, ph]]; continue; }
        NSError *err = nil;
        NSDictionary *opts = @{NSWorkspaceDesktopImageScalingKey: @(NSImageScaleProportionallyUpOrDown),
                               NSWorkspaceDesktopImageAllowClippingKey: @YES};
        BOOL ok = [[NSWorkspace sharedWorkspace] setDesktopImageURL:[NSURL fileURLWithPath:file]
                                                          forScreen:screen options:opts error:&err];
        [lines addObject:[NSString stringWithFormat:@"%@: %zux%zu %@", screen.localizedName, pw, ph,
                          ok ? @"set" : [NSString stringWithFormat:@"not set (%@)", err.localizedDescription]]];
    }
    self.procText = [lines componentsJoinedByString:@"\n"];
    NSLog(@"%@", self.procText);
    [self notifyOfCompletionInMainThread];
}

- (NSString*)outputDirectory {
    NSString *directoryForOutput = [NSString stringWithFormat:[@"~/Pictures/MultiScape/%f" stringByExpandingTildeInPath],
                                    [[NSDate date] timeIntervalSince1970]];
        
    if(![fileManager fileExistsAtPath:[@"~/Pictures/MultiScape" stringByExpandingTildeInPath]]) {
        [fileManager createDirectoryAtPath:[@"~/Pictures/MultiScape" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [fileManager createDirectoryAtPath:directoryForOutput withIntermediateDirectories:YES attributes:nil error:nil];
    
    return directoryForOutput;
}

- (CIImage*)scaleImage:(CIImage*)imageToScale byFactor:(double)scaleFactor {
    CIFilter *scaleTransformFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    [scaleTransformFilter setValue:[NSNumber numberWithDouble:scaleFactor] forKey:@"inputScale"];
    [scaleTransformFilter setValue:imageToScale forKey:@"inputImage"];
    [scaleTransformFilter setValue:[NSNumber numberWithInt:1] forKey:@"inputAspectRatio"];
    
    CIImage *scaledBaseImage = [scaleTransformFilter valueForKey:@"outputImage"];
    NSLog(@"Scaled base image dimensions: %f x %f",[scaledBaseImage extent].size.width, [scaledBaseImage extent].size.height);
    return [scaleTransformFilter valueForKey:@"outputImage"];
}

- (void)saveImageToFile:(NSString*)fileLocation
               imageRep:(NSBitmapImageRep*)outputBitmapImageRep {
    NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:0.95], NSImageCompressionFactor, [NSNumber numberWithBool:FALSE], NSImageProgressive, nil];
    NSData *outputData = [outputBitmapImageRep representationUsingType:NSJPEGFileType properties:properties];
    [outputData writeToFile:fileLocation atomically:NO];
}

@end
