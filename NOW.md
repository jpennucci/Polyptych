# Now

Local clone of nitantsoni/multiscape (no releases upstream), built and installed to /Applications. Read first, update last.

- 2026-11-25: built with Xcode 27.1 (arm64, ad-hoc signed), installed to /Applications/MultiScape.app.
- Fixed: crash on launch with 2+ monitors. MSBackgroundWorker.m allocated 20 bytes for 20 CGSizes (heap overflow);
  now calloc(maxDisplays, sizeof(CGSize)). Not sent upstream.
- Rebuild: `xcodebuild -project MultiScape.xcodeproj -scheme MultiScape -configuration Release -derivedDataPath build/dd CODE_SIGN_IDENTITY=- build`
