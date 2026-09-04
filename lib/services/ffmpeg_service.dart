import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class FfmpegException implements Exception {
  final String message;
  FfmpegException(this.message);
  @override
  String toString() => message;
}

/// Wraps the FFmpeg binary bundled next to the app executable to transcode
/// video files. Falls back to a `ffmpeg` on PATH when running via
/// `flutter run` in development, where no bundled binary exists.
class FfmpegService {
  static final RegExp _durationRe = RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)');
  static final RegExp _timeRe = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)');

  String get _ffmpegPath {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final bundled = p.join(exeDir, 'ffmpeg.exe');
    if (File(bundled).existsSync()) return bundled;
    return 'ffmpeg';
  }

  Duration _parseTimestamp(RegExpMatch m) {
    final hours = int.parse(m.group(1)!);
    final minutes = int.parse(m.group(2)!);
    final seconds = double.parse(m.group(3)!);
    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
  }

  List<String> _buildArgs(String input, String output, String preset, int crf) {
    return [
      '-y',
      '-i', input,
      '-c:v', 'libx264',
      '-preset', preset,
      '-crf', '$crf',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      output,
    ];
  }

  (String, int) _presetFor(String qualityPreset) {
    switch (qualityPreset) {
      case 'fast':
        return ('veryfast', 26);
      case 'best':
        return ('slow', 18);
      default:
        return ('medium', 23);
    }
  }

  /// Converts [input] to [output]. Calls [onStarted] as soon as the process
  /// launches (so the caller can cancel it later) and [onProgress] with a
  /// value in [0, 1] as FFmpeg reports encoding progress. Throws
  /// [FfmpegException] if the process exits with a non-zero code.
  Future<void> convert({
    required String input,
    required String output,
    required String qualityPreset,
    required void Function(Process process) onStarted,
    required void Function(double progress) onProgress,
  }) async {
    final (preset, crf) = _presetFor(qualityPreset);

    final process = await Process.start(_ffmpegPath, _buildArgs(input, output, preset, crf));
    onStarted(process);

    Duration? totalDuration;
    final stderrLines = <String>[];
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrLines.add(line);
      if (stderrLines.length > 40) stderrLines.removeAt(0);

      if (totalDuration == null) {
        final durationMatch = _durationRe.firstMatch(line);
        if (durationMatch != null) totalDuration = _parseTimestamp(durationMatch);
      }

      final timeMatch = _timeRe.firstMatch(line);
      final total = totalDuration;
      if (timeMatch != null && total != null && total.inMilliseconds > 0) {
        final current = _parseTimestamp(timeMatch);
        final fraction = current.inMilliseconds / total.inMilliseconds;
        onProgress(fraction.clamp(0.0, 1.0));
      }
    }).asFuture<void>();

    process.stdout.drain<void>();

    final exitCode = await process.exitCode;
    await stderrDone.catchError((_) {});

    if (exitCode != 0) {
      throw FfmpegException(
        stderrLines.isNotEmpty ? stderrLines.last : 'ffmpeg exited with code $exitCode',
      );
    }
    onProgress(1.0);
  }
}
