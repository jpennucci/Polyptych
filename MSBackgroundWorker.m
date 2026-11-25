//
//  MSBackgroundWorker.m
//  MultiScape
//
//  Created by David Zwerdling on 11/11/10.
//  Copyright 2010 Laughing Man Software. All rights reserved.
//  Modified 2026-11-25 by James Pennucci for Polyptych: displays of any size, rotation and resolution from the
//  Displays arrangement; seven layouts; NSWorkspace and System Events by display id; old runs cleaned up.
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
    BOOL several = [[NSScreen screens] count] > 1;
    MSLayout layout = self.layout;
    if (layout == MSLayoutAuto) {
        // Wide enough to span; otherwise the screen whose shape fits best, filled unless that would cut a lot.
        if (aspect >= MSSpanAspect || !several) {
            layout = MSLayoutSpanFill;
        } else {
            NSScreen *best = [self screenForAspect:aspect];
            CGFloat sa = best.frame.size.width / best.frame.size.height;
            layout = fabs(log(aspect / sa)) < log(1.25) ? MSLayoutOneFill : MSLayoutOneFit;
        }
    }
    BOOL spanFill = layout == MSLayoutSpanFill, spanFit = layout == MSLayoutSpanFit;
    BOOL each = layout == MSLayoutEachFill || layout == MSLayoutEachFit;
    BOOL one = layout == MSLayoutOneFill || layout == MSLayoutOneFit;
    BOOL fill = layout == MSLayoutEachFill || layout == MSLayoutOneFill;
    NSScreen *featured = one ? [self screenForAspect:aspect] : nil;

    // The spread across every screen: the picture covering it (span fill), or a blurred copy covering it with,
    // for span fit, the whole picture over it, centred.
    double scale = MAX(_perfectSize.width / b.size.width, _perfectSize.height / b.size.height);
    CGRect se = CGRectMake(0, 0, b.size.width * scale, b.size.height * scale);
    CIImage *source = spanFill ? [self scaleImage:base byFactor:scale]
                               : [self backdropFrom:base coverScale:scale extent:se];
    se = [source extent];
    CGFloat offX = se.origin.x + (se.size.width - _perfectSize.width) / 2.0;
    CGFloat offY = se.origin.y + (se.size.height - _perfectSize.height) / 2.0;
    if (spanFit) {
        double fitScale = MIN(_perfectSize.width / b.size.width, _perfectSize.height / b.size.height);
        CIImage *whole = [self scaleImage:base byFactor:fitScale];
        CGRect we = [whole extent];
        whole = [whole imageByApplyingTransform:CGAffineTransformMakeTranslation(
                     offX + (_perfectSize.width - we.size.width) / 2.0 - we.origin.x,
                     offY + (_perfectSize.height - we.size.height) / 2.0 - we.origin.y)];
        source = [[whole imageByCompositingOverImage:source] imageByCroppingToRect:se];
    }

    NSString *outputDirectory = [self outputDirectory];
    CIContext *ctx = [CIContext contextWithOptions:nil];
    NSArray *names = @[@"auto", @"spans all screens, filled", @"spans all screens, whole",
                       @"on each screen, filled", @"on each screen, whole", @"filled", @"whole"];
    NSMutableArray *lines = [NSMutableArray arrayWithObject:
        one ? [NSString stringWithFormat:@"%.0fx%.0f on %@, %@, blurred on the rest", b.size.width, b.size.height,
                                         featured.localizedName, names[layout]]
            : [NSString stringWithFormat:@"%.0fx%.0f %@", b.size.width, b.size.height, names[layout]]];
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
            piece = (spanFill || spanFit) ? [self scaleImage:piece byFactor:own]
                                          : [piece imageByApplyingTransform:CGAffineTransformMakeScale(own, own)];
        }
        if (each || screen == featured) {
            // The whole picture on this screen alone: filling it (cropped), or fitted over the blur.
            double s2 = fill ? MAX(pw / b.size.width, ph / b.size.height) : MIN(pw / b.size.width, ph / b.size.height);
            CIImage *sharp = [self scaleImage:base byFactor:s2];
            CGRect xe = [sharp extent];
            sharp = [sharp imageByApplyingTransform:CGAffineTransformMakeTranslation((pw - xe.size.width) / 2.0 - xe.origin.x,
                                                                                     (ph - xe.size.height) / 2.0 - xe.origin.y)];
            if (each && !fill) {
                // Each screen's own blur behind it, so the bars match the picture on that screen.
                double cs = MAX(pw / b.size.width, ph / b.size.height);
                CGRect ce = CGRectMake(0, 0, b.size.width * cs, b.size.height * cs);
                CIImage *ownBlur = [self backdropFrom:base coverScale:cs extent:ce];
                CGRect oe = [ownBlur extent];
                piece = [ownBlur imageByApplyingTransform:CGAffineTransformMakeTranslation((pw - oe.size.width) / 2.0 - oe.origin.x,
                                                                                       (ph - oe.size.height) / 2.0 - oe.origin.y)];
            }
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
        // NSWorkspace can say yes and change nothing (it set a Space the screen isn't showing: seen on a second
        // identical 27"). System Events, by the display's own ID, sets every Space on that screen.
        ok = [self systemEventsSet:file onDisplay:[screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue]] || ok;
        [lines addObject:[NSString stringWithFormat:@"%@: %zux%zu %@", screen.localizedName, pw, ph,
                          ok ? @"set" : [NSString stringWithFormat:@"not set (%@)", err.localizedDescription]]];
    }
    self.procText = [lines componentsJoinedByString:@"\n"];
    NSLog(@"%@", self.procText);
    [self notifyOfCompletionInMainThread];
}

- (BOOL)systemEventsSet:(NSString *)file onDisplay:(uint32_t)displayID {
    NSString *escaped = [[file stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                         stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *src = [NSString stringWithFormat:
        @"tell application \"System Events\"\n"
         "  repeat with d in desktops\n"
         "    if (id of d) is %u then set picture of d to POSIX file \"%@\"\n"
         "  end repeat\n"
         "end tell", displayID, escaped];
    NSDictionary *error = nil;
    [[[NSAppleScript alloc] initWithSource:src] executeAndReturnError:&error];
    if (error) NSLog(@"System Events didn't set display %u: %@", displayID, error[NSAppleScriptErrorMessage]);
    return error == nil;
}

- (NSString*)outputDirectory {
    NSString *directoryForOutput = [NSString stringWithFormat:[@"~/Pictures/Polyptych/%f" stringByExpandingTildeInPath],
                                    [[NSDate date] timeIntervalSince1970]];
        
    if(![fileManager fileExistsAtPath:[@"~/Pictures/Polyptych" stringByExpandingTildeInPath]]) {
        [fileManager createDirectoryAtPath:[@"~/Pictures/Polyptych" stringByExpandingTildeInPath] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // Keep the last few runs (the wallpaper in use is always among them), not one more folder a day forever.
    NSString *root = [@"~/Pictures/Polyptych" stringByExpandingTildeInPath];
    NSArray *runs = [[[fileManager contentsOfDirectoryAtPath:root error:nil]
                      filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF MATCHES '^[0-9]+\\.[0-9]+$'"]]
                     sortedArrayUsingComparator:^(NSString *a, NSString *b) { return [@(b.doubleValue) compare:@(a.doubleValue)]; }];
    // Never one a screen or a Space still shows: macOS's wallpaper store names the files it uses.
    NSData *store = [NSData dataWithContentsOfFile:[@"~/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
                                                    stringByExpandingTildeInPath]];
    for (NSUInteger i = 4; i < runs.count; i++) {
        NSData *name = [runs[i] dataUsingEncoding:NSUTF8StringEncoding];
        if (store && [store rangeOfData:name options:0 range:NSMakeRange(0, store.length)].location != NSNotFound) continue;
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
