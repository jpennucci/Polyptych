# Now

Polyptych: James's GPL v3 fork of nitantsoni/multiscape (github.com/jpennucci/Polyptych). Read first, update last.

- 2026-11-25: built with Xcode 27.1 (arm64, ad-hoc signed), installed to /Applications/MultiScape.app (now Polyptych.app).
- Fixed: crash on launch with 2+ monitors. MSBackgroundWorker.m allocated 20 bytes for 20 CGSizes (heap overflow);
  now calloc(maxDisplays, sizeof(CGSize)). Not sent upstream.
- 2026-11-25: displays of any size, rotation and resolution. MSBackgroundWorker reads NSScreen frames (the
  Displays arrangement, rotation applied), covers their union with the picture (centred, no stretch), cuts each
  screen's rect at its own pixels (2x for Retina) and sets it with NSWorkspace setDesktopImageURL:forScreen:
  (no System Events, no permission). Checked with a grid on James's 3 Dells (43" landscape 1x between two 27"
  portrait 2x): seams continuous. dryRun makes the pictures without setting them.
- 2026-11-25: daily change from a folder (MSDaily): Choose… / Change daily / Change now under the drop area. A launch
  agent (~/Library/LaunchAgents/com.multiscape.daily.plist) runs `MultiScape --daily` at 06:00 and at login: the next
  picture from a shuffled round of the folder and its subfolders, no window. Pictures 2:1 or wider span every screen;
  narrower ones go whole on the screen whose shape fits best (portrait on a 27"), over a blurred copy on the rest.
  Output keeps the last 4 runs in ~/Pictures/MultiScape. Checked with dry runs (3:2, 2:3) and the window; the agent
  not yet run by launchd with a folder (James to choose one). Log: ~/Library/Logs/MultiScape-daily.log.
- 2026-11-25: Layout menu (Auto, Span fill / fit, Each screen fill / fit, One screen fill / fit; a change re-applies
  the current picture) and Change menu (Off, Every hour, Every day at 6:00; all also at login). Auto fills the best
  screen when its shape is within 25% (a 3:2 photo fills the 43"). All 7 checked by dry run on a 3:2 grid; the hourly
  agent checked with launchd on an empty folder (ran at load, exit 0), then removed. Bundle id is still
  com.yourcompany.MultiScape (its settings live there).
- 2026-11-25: right 27" didn't change: NSWorkspace setDesktopImageURL said yes and changed nothing (that display
  has two Spaces on record). Now each screen is also set through System Events by display id (`id of desktop` =
  CGDirectDisplayID; its display names are numbered the other way round from NSScreen's, never match by name), with
  NSAppleEventsUsageDescription back. Cleanup skips any run folder named in
  ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist. Ad-hoc signing: every rebuild asks for the
  System Events permission again.
- 2026-11-25: renamed Polyptych 1.0.0 (com.jpennucci.Polyptych; agent com.jpennucci.polyptych; ~/Pictures/Polyptych;
  ~/Library/Logs/Polyptych.log). README with credits and changes, NSHumanReadableCopyright credits David Zwerdling
  and Nitant Soni. James's Mac moved over: MultiScape.app and its agent removed, settings copied (Desktop Wallpaper,
  Span fill, hourly), first hourly run set all 3. Released on GitHub as a fork of nitantsoni/multiscape, v1.0.0,
  ad-hoc signed (no Developer ID: Open Anyway). Old ~/Pictures/MultiScape can go once nothing shows from it.
- 2026-11-25: preview over the drop area: the screens as arranged, each with what it shows (MSLastSet, else
  NSWorkspace), refreshed after any run, the agent's too (distributed notification com.jpennucci.polyptych.changed).
- Open: only the current Space on each screen gets it (macOS sets wallpaper per Space). Bezel gaps not modelled.
- Rebuild: `xcodebuild -project MultiScape.xcodeproj -scheme MultiScape -configuration Release -derivedDataPath build/dd CODE_SIGN_IDENTITY=- build`
