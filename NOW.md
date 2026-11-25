# Now

Local clone of nitantsoni/multiscape (no releases upstream), built and installed to /Applications. Read first, update last.

- 2026-11-25: built with Xcode 27.1 (arm64, ad-hoc signed), installed to /Applications/MultiScape.app.
- Fixed: crash on launch with 2+ monitors. MSBackgroundWorker.m allocated 20 bytes for 20 CGSizes (heap overflow);
  now calloc(maxDisplays, sizeof(CGSize)). Not sent upstream.
- 2026-11-25: displays of any size, rotation and resolution. MSBackgroundWorker reads NSScreen frames (the
  Displays arrangement, rotation applied), covers their union with the picture (centred, no stretch), cuts each
  screen's rect at its own pixels (2x for Retina) and sets it with NSWorkspace setDesktopImageURL:forScreen:
  (no System Events, no permission). Checked with a grid on James's 3 Dells (43" landscape 1x between two 27"
  portrait 2x): seams continuous. dryRun makes the pictures without setting them.
- Open: only the current Space on each screen gets it (macOS sets wallpaper per Space). Bezel gaps not modelled.
- Rebuild: `xcodebuild -project MultiScape.xcodeproj -scheme MultiScape -configuration Release -derivedDataPath build/dd CODE_SIGN_IDENTITY=- build`
