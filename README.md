# Polyptych

A wallpaper for Macs with several displays of different sizes, orientations and resolutions: one picture across all
of them, lined up the way they sit on your desk, or a new one from a folder every hour or every day.

A *polyptych* is a painting made of several panels. Polyptych makes one out of your screens.

## What it does

- **Follows your arrangement.** Each screen's place, size and rotation come from System Settings > Displays, so a
  landscape 43" between two portrait 27"s, each a little lower, lines up: the horizon stays level across the seams.
- **Sharp on every screen.** Each screen gets its piece at its own pixel count (2x on Retina and scaled 4K).
- **Seven layouts:**
  - **Auto:** a picture 2:1 or wider spans every screen; a narrower one goes on the screen whose shape fits it best.
  - **Span, fill:** one picture across all screens, as wide as all of them; a regular picture loses its top and bottom.
  - **Span, fit:** the whole picture across all screens, nothing cut, a blur of it around.
  - **Each screen, fill / fit:** the same picture on every screen.
  - **One screen, fill / fit:** the best-shaped screen gets the picture; the others a blur of it.
- **A preview** of what each screen shows, laid out like your screens, kept up to date.
- **A new picture every hour or every day** (and at login) from a folder you choose, its subfolders included, each
  picture once before any comes round again.

## Install

1. Download `Polyptych.zip` from [Releases](../../releases), unzip it and move **Polyptych** to Applications.
2. Open it. It isn't notarized by Apple, so macOS stops it the first time: open **System Settings > Privacy &
   Security**, scroll down to "Polyptych was blocked" and click **Open Anyway**.
3. When it first sets a wallpaper, macOS asks whether Polyptych may control **System Events**. Click **Allow**: some
   screens only take a new wallpaper that way.

Needs macOS 12 or later.

## Use

- **Drop a picture** on the window: it's set at once, with the chosen layout.
- **Folder:** Choose… a folder of pictures. **Change:** Off, Every hour or Every day at 6:00. **Change now** moves on
  to the next picture. Changing the **Layout** shows the current picture again in the new one.
- The size at the top is the picture size that fills every screen at full sharpness: a panorama about that shape
  spans best.

The pieces are saved in `~/Pictures/Polyptych` (the last few runs, and any a desktop still uses). The hourly or daily
change is a launch agent (`~/Library/LaunchAgents/com.jpennucci.polyptych.plist`) that runs `Polyptych --daily` and
quits; Change: Off removes it. Its log is `~/Library/Logs/Polyptych.log`.

## Known limits

- macOS keeps a wallpaper per desktop (Space); the hourly or daily change sets the ones showing on each screen.
- The gaps between screens (bezels) aren't allowed for, so a line crossing a seam jumps by the bezel's width.

## Build

```sh
xcodebuild -project MultiScape.xcodeproj -scheme MultiScape -configuration Release \
  -derivedDataPath build/dd CODE_SIGN_IDENTITY=- build
```

The app is `build/dd/Build/Products/Release/Polyptych.app`.

## Credits and licence

Polyptych is a fork of **MultiScape** by **David Zwerdling** (Laughing Man Software, 2010), by way of
[Nitant Soni's fork](https://github.com/nitantsoni/multiscape), with earlier work by Robbie Trencheny and fangrui.
`AEVTBuilder` is by Michael Ash (Ultralingua, 2005, zlib licence, see its header).

Changes for Polyptych (2026, James Pennucci): screens of any size, rotation and resolution from the Displays
arrangement; the seven layouts; the folder, hourly and daily change; setting each screen through NSWorkspace and
System Events by display ID; a crash on launch with two or more displays fixed (20 bytes allocated for 20 screen
sizes); wallpapers that were never set (a path given as a web URL). Each changed file says so in its header.

Polyptych is free software under the **GNU General Public License v3** (see [LICENSE](LICENSE)), as MultiScape was.
You may copy, change and share it under the same licence, with its source.
