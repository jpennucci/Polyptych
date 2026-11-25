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

// A picture at least this wide (width / height) spans every screen. A narrower one is shown whole on the screen
// whose shape matches it best, over a blurred copy of itself spread across all of them.
static const CGFloat MSSpanAspect = 2.0;

- (CIImage *)backdropFrom:(CIImage *)base coverScale:(double)scale extent:(CGRect)se {
    // Blur a small copy and scale it back up: the same look as blurring the full size, far less work.
    const double small = 0.08;
    CIImage *tiny = [self scaleImage:base byFactor:scale * small];
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blur setValue:[tiny imageByClampingToExtent] forKey:kCIInputImageKey];
    [blur setValue:@(MAX(tiny.extent.size.width, tiny.extent.size.height) * 0.025) forKey:kCIInputRadiusKey];  // 2.5% of the spread
    CIFilter *dim = [CIFilter filterWithName:@"CIColorControls"];
    [dim setValue:blur.outputImage forKey:kCIInputImageKey];
    [dim setValue:@(-0.12) forKey:kCIInputBrightnessKey];
    [dim setValue:@(0.9) forKey:kCIInputSaturationKey];
    CGRect te = [tiny extent];
    CIImage *up = [dim.outputImage imageByApplyingTransform:CGAffineTransformMakeScale(se.size.width / te.size.width,
                                                                                         se.size.height / te.size.height)];
    return [up imageByCroppingToRect:se];
}

- (NSScreen *)screenForAspect:(CGFloat)aspect {
    NSScreen *best = nil; CGFloat bestScore = CGFLOAT_MAX;
    for (NSScreen *screen in [NSScreen screens]) {
        CGFloat sa = screen.frame.size.width / screen.frame.size.height;
        // How far apart the shapes are, then the bigger screen on a tie.
        CGFloat score = fabs(log(aspect / sa)) - 0.0001 * log(screen.frame.size.width * screen.frame.size.height);
        if (score < bestScore) { bestScore = score; best = screen; }
    }
    return best;
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
    CGFloat aspect = b.size.width / b.size.height;
    BOOL span = aspect >= MSSpanAspect || [[NSScreen screens] count] < 2;
    NSScreen *featured = span ? nil : [self screenForAspect:aspect];

    // Cover the canvas (no stretching), centred: the overhang is cropped equally from both sides.
    double scale = MAX(_perfectSize.width / b.size.width, _perfectSize.height / b.size.height);
    CIImage *scaled = span ? [self scaleImage:base byFactor:scale] : nil;
    CGRect se = CGRectMake(0, 0, b.size.width * scale, b.size.height * scale);
    CIImage *source = span ? scaled : [self backdropFrom:base coverScale:scale extent:se];
    se = [source extent];
    CGFloat offX = se.origin.x + (se.size.width - _perfectSize.width) / 2.0;
    CGFloat offY = se.origin.y + (se.size.height - _perfectSize.height) / 2.0;

    NSString *outputDirectory = [self outputDirectory];
    CIContext *ctx = [CIContext contextWithOptions:nil];
    NSMutableArray *lines = [NSMutableArray arrayWithObject:
        span ? [NSString stringWithFormat:@"%.0fx%.0f spans all screens (%.0fx%.0f)", b.size.width, b.size.height,
                                          _perfectSize.width, _perfectSize.height]
             : [NSString stringWithFormat:@"%.0fx%.0f on %@, blurred behind on the rest", b.size.width, b.size.height,
                                          featured.localizedName]];
    NSUInteger n = 0;
    for (NSScreen *screen in [NSScreen screens]) {
        NSRect f = screen.frame;
        size_t pw = (size_t)llround(f.size.width * screen.backingScaleFactor);
        size_t ph = (size_t)llround(f.size.height * screen.backingScaleFactor);
        // This screen's rectangle of the spread (Core Image and Cocoa both count y up from the bottom).
        CGRect r = CGRectMake(offX + (f.origin.x - _canvas.origin.x) * _maxScale,
                              offY + (f.origin.y - _canvas.origin.y) * _maxScale,
                              f.size.width * _maxScale, f.size.height * _maxScale);
        CIImage *piece = [[source imageByCroppingToRect:r]
                          imageByApplyingTransform:CGAffineTransformMakeTranslation(-r.origin.x, -r.origin.y)];
        CGFloat own = screen.backingScaleFactor / _maxScale;  // down to this screen's own pixels
        if (own < 1.0) {
            piece = span ? [self scaleImage:piece byFactor:own]
                         : [piece imageByApplyingTransform:CGAffineTransformMakeScale(own, own)];
        }
        if (screen == featured) {
            // The whole picture, sharp: filling the screen when the shapes are close, else fitted over the blur.
            CGFloat sa = (CGFloat)pw / ph;
            BOOL cover = fabs(log(aspect / sa)) < log(1.15);
            double s2 = cover ? MAX(pw / b.size.width, ph / b.size.height) : MIN(pw / b.size.width, ph / b.size.height);
            CIImage *sharp = [self scaleImage:base byFactor:s2];
            CGRect xe = [sharp extent];
            sharp = [sharp imageByApplyingTransform:CGAffineTransformMakeTranslation((pw - xe.size.width) / 2.0 - xe.origin.x,
                                                                                     (ph - xe.size.height) / 2.0 - xe.origin.y)];
            piece = [sharp imageByCompositingOverImage:piece];
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
    // Keep the last few runs (the wallpaper in use is always among them), not one more folder a day forever.
    NSString *root = [@"~/Pictures/MultiScape" stringByExpandingTildeInPath];
    NSArray *runs = [[[fileManager contentsOfDirectoryAtPath:root error:nil]
                      filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF MATCHES '^[0-9]+\\.[0-9]+$'"]]
                     sortedArrayUsingComparator:^(NSString *a, NSString *b) { return [@(b.doubleValue) compare:@(a.doubleValue)]; }];
    for (NSUInteger i = 4; i < runs.count; i++) {
        [fileManager removeItemAtPath:[root stringByAppendingPathComponent:runs[i]] error:nil];
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
    return [scaleTransformFilter valueForKey:@"outputImage"];
}

- (void)saveImageToFile:(NSString*)fileLocation
               imageRep:(NSBitmapImageRep*)outputBitmapImageRep {
    NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:0.95], NSImageCompressionFactor, [NSNumber numberWithBool:FALSE], NSImageProgressive, nil];
    NSData *outputData = [outputBitmapImageRep representationUsingType:NSJPEGFileType properties:properties];
    [outputData writeToFile:fileLocation atomically:NO];
}

@end
