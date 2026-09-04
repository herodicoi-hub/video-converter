import 'dart:io';

import 'package:path/path.dart' as p;

enum JobStatus { queued, converting, done, error, canceled }

class ConversionJob {
  final String id;
  final String sourcePath;
  String outputPath;
  JobStatus status;
  double progress;
  String? errorMessage;
  bool cancelRequested;
  Process? process;

  ConversionJob({
    required this.id,
    required this.sourcePath,
    required this.outputPath,
    this.status = JobStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    this.cancelRequested = false,
  });

  String get fileName => p.basename(sourcePath);
  String get outputFileName => p.basename(outputPath);
}
