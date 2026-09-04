import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the user's last-used format, quality, and output folder
/// choices between launches.
class SettingsService {
  static const _formatKey = 'format';
  static const _qualityKey = 'quality';
  static const _outputDirKey = 'output_dir';

  Future<Map<String, String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'format': prefs.getString(_formatKey) ?? 'mp4',
      'quality': prefs.getString(_qualityKey) ?? 'balanced',
      'outputDir': prefs.getString(_outputDirKey),
    };
  }

  Future<void> saveFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_formatKey, format);
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
