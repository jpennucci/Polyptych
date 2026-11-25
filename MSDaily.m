//  MSDaily.m: a new wallpaper every day from a folder, set by a launch agent running MultiScape --daily.
//  GPL v3, as the rest of MultiScape.

#import "MSDaily.h"
#import "MSBackgroundWorker.h"

static NSString *const MSFolderKey = @"MSDailyFolder";
static NSString *const MSQueueKey = @"MSDailyQueue";      // pictures still to show this round, shuffled
static NSString *const MSLastKey = @"MSDailyLast";
static NSString *const MSAgentLabel = @"com.multiscape.daily";
static const NSInteger MSHour = 6;                        // 06:00, or at wake / login if the Mac was off

@implementation MSDaily

+ (NSUserDefaults *)defaults {
    return [NSUserDefaults standardUserDefaults];  // the window and the agent's --daily run are the same app
}

+ (NSString *)folder { return [[self defaults] stringForKey:MSFolderKey]; }

+ (void)setFolder:(NSString *)folder {
    NSUserDefaults *d = [self defaults];
    [d setObject:folder forKey:MSFolderKey];
    [d removeObjectForKey:MSQueueKey];  // a new folder starts a new round
}

+ (NSString *)agentPath {
    return [[NSString stringWithFormat:@"~/Library/LaunchAgents/%@.plist", MSAgentLabel] stringByExpandingTildeInPath];
}

+ (BOOL)isEnabled { return [[NSFileManager defaultManager] fileExistsAtPath:[self agentPath]]; }

+ (int)launchctl:(NSArray *)args {
    NSTask *t = [[NSTask alloc] init];
    t.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
    t.arguments = args;
    t.standardOutput = [NSFileHandle fileHandleWithNullDevice];
    t.standardError = [NSFileHandle fileHandleWithNullDevice];
    if (![t launchAndReturnError:nil]) return -1;
    [t waitUntilExit];
    return t.terminationStatus;
}

+ (NSString *)setEnabled:(BOOL)on {
    NSString *domain = [NSString stringWithFormat:@"gui/%d", getuid()];
    NSString *path = [self agentPath];
    [self launchctl:@[@"bootout", [NSString stringWithFormat:@"%@/%@", domain, MSAgentLabel]]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    if (!on) return nil;
    if (![self folder]) return @"Choose a folder first.";

    NSDictionary *agent = @{
        @"Label": MSAgentLabel,
        @"ProgramArguments": @[[[NSBundle mainBundle] executablePath], @"--daily"],
        @"StartCalendarInterval": @{@"Hour": @(MSHour), @"Minute": @0},
        @"RunAtLoad": @YES,                 // and at login
        @"ProcessType": @"Background",
        @"StandardErrorPath": [@"~/Library/Logs/MultiScape-daily.log" stringByExpandingTildeInPath],
    };
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    NSError *err = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:agent format:NSPropertyListXMLFormat_v1_0
                                                             options:0 error:&err];
    if (!data || ![data writeToFile:path atomically:YES]) return @"Couldn't write the launch agent.";
    if ([self launchctl:@[@"bootstrap", domain, path]] != 0) return @"launchctl wouldn't load the launch agent.";
    return nil;
}

+ (NSArray<NSString *> *)picturesIn:(NSString *)folder {
    NSSet *kinds = [NSSet setWithArray:@[@"jpg", @"jpeg", @"png", @"heic", @"heif", @"tif", @"tiff", @"webp", @"gif", @"bmp"]];
    NSMutableArray *found = [NSMutableArray array];
    NSDirectoryEnumerator *e = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:folder]
        includingPropertiesForKeys:nil
        options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants
        errorHandler:nil];
    for (NSURL *u in e) {
        if ([kinds containsObject:u.pathExtension.lowercaseString]) {
            [found addObject:[u.path substringFromIndex:folder.length]];  // relative, so a renamed parent still works
        }
    }
    return found;
}

+ (NSString *)nextPicture {
    NSUserDefaults *d = [self defaults];
    NSString *folder = [self folder];
    NSArray *all = [self picturesIn:folder];
    if (all.count == 0) return nil;
    NSMutableArray *queue = [[d arrayForKey:MSQueueKey] mutableCopy] ?: [NSMutableArray array];
    [queue filterUsingPredicate:[NSPredicate predicateWithFormat:@"SELF IN %@", all]];  // gone since
    if (queue.count == 0) {
        queue = [all mutableCopy];
        for (NSUInteger i = queue.count; i > 1; i--) [queue exchangeObjectAtIndex:i - 1 withObjectAtIndex:arc4random_uniform((uint32_t)i)];
        NSString *last = [d stringForKey:MSLastKey];
        if (queue.count > 1 && [queue.firstObject isEqualToString:last]) [queue exchangeObjectAtIndex:0 withObjectAtIndex:queue.count - 1];
    }
    NSString *next = queue.firstObject;
    [queue removeObjectAtIndex:0];
    [d setObject:queue forKey:MSQueueKey];
    [d setObject:next forKey:MSLastKey];
    return [folder stringByAppendingString:next];
}

+ (NSString *)changeNow {
    NSString *folder = [self folder];
    if (!folder) return @"No folder chosen.";
    if (![[NSFileManager defaultManager] fileExistsAtPath:folder]) return [NSString stringWithFormat:@"%@ isn't there (a drive not connected?).", folder];
    NSString *path = [self nextPicture];
    if (!path) return [NSString stringWithFormat:@"No pictures in %@.", folder];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
    if (!image) return [NSString stringWithFormat:@"Couldn't open %@.", path.lastPathComponent];
    MSBackgroundWorker *w = [[MSBackgroundWorker alloc] init];
    w.baseImage = image;
    [w execute];
    return [NSString stringWithFormat:@"%@\n%@", path.lastPathComponent, w.procText];
}

@end
