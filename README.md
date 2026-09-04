# Video Converter

A Windows desktop app that converts any video file to **MP4** or **MOV**.

Drag and drop one or more video files onto the app (or use Browse), pick
MP4 or MOV and a quality level, and hit Convert. Everything happens locally
on your machine - no uploads, no accounts, no internet needed.

## What it does

- **Drag & drop** video files (or a whole folder of them) to queue them up.
- Converts to **MP4** or **MOV**, using the widely-compatible H.264 video /
  AAC audio combination so the output plays everywhere.
- **Quality presets**: Fast, Balanced, or Best quality (trades off
  conversion speed against file size/sharpness).
- Converts files **one at a time** with a live progress bar per file, and
  you can cancel any file mid-conversion.
- Choose where converted files are saved - next to each original by
  default, or a folder of your choosing.
- Once a file is done, **Play** it or **Show in folder** right from the
  list.
- Remembers your last-used format, quality, and output folder for next
  time.

## How this gets built

There is no Flutter installed on this machine - the Windows app is built in
the cloud by **GitHub Actions** every time code is pushed to the `main`
branch (see `.github/workflows/build.yml`). The `windows/` platform folder
is intentionally not committed - the workflow regenerates it with
`flutter create .` and builds it fresh each time. The build also downloads
a standalone **FFmpeg** (the free, open-source engine that does the actual
video conversion) and packages it right alongside the app - you don't need
to install FFmpeg yourself.

To get the built app:

1. Push your changes to GitHub.
2. Go to the repo's **Actions** tab and wait for the run to finish (green
   check).
3. Open that run → **Artifacts** → download `video-converter-windows`.
4. Unzip it (all the files in the zip, including `ffmpeg.exe`, need to stay
   together in the same folder) and run `video_converter.exe`.

## Project layout

```
lib/
  main.dart                     entry point
  models/conversion_job.dart    a single file's conversion state (queued/converting/done/error)
  services/
    ffmpeg_service.dart         runs the bundled ffmpeg.exe and parses its progress output
    settings_service.dart       remembers last-used format/quality/output folder
  screens/home_screen.dart      the whole app: drop zone, queue, controls
  widgets/
    drop_zone.dart              the drag-and-drop area shown when the queue is empty
    job_tile.dart                one row in the conversion queue
```

## Limits and honest expectations

Conversion speed depends on your PC's CPU and the video's length/resolution
- a long 4K file on "Best quality" can take a while. If a file fails to
convert, it's usually because the file is corrupted or FFmpeg couldn't
read it; try the "Fast" preset first, or check the file plays in a normal
media player.
