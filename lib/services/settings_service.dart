import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the user's last-used mode, format, quality, and output folder
/// choices between launches.
class SettingsService {
  static const _modeKey = 'mode';
  static const _videoFormatKey = 'format';
  static const _audioFormatKey = 'audio_format';
  static const _qualityKey = 'quality';
  static const _outputDirKey = 'output_dir';

  Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'mode': prefs.getString(_modeKey) ?? 'video',
      'videoFormat': prefs.getString(_videoFormatKey) ?? 'mp4',
      'audioFormat': prefs.getString(_audioFormatKey) ?? 'mp3',
      'quality': prefs.getString(_qualityKey) ?? 'balanced',
      'outputDir': prefs.getString(_outputDirKey),
    };
  }

  Future<void> saveMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode);
  }

  Future<void> saveVideoFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_videoFormatKey, format);
  }

  Future<void> saveAudioFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioFormatKey, format);
  }

  Future<void> saveQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qualityKey, quality);
  }

  Future<void> saveOutputDir(String? dir) async {
    final prefs = await SharedPreferences.getInstance();
    if (dir == null) {
      await prefs.remove(_outputDirKey);
    } else {
      await prefs.setString(_outputDirKey, dir);
    }
  }
}
