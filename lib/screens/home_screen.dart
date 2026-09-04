import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/conversion_job.dart';
import '../services/ffmpeg_service.dart';
import '../services/settings_service.dart';
import '../widgets/drop_zone.dart';
import '../widgets/job_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ffmpeg = FfmpegService();
  final _settings = SettingsService();

  final List<ConversionJob> _jobs = [];
  String _format = 'mp4';
  String _quality = 'balanced';
  String? _customOutputDir;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final saved = await _settings.load();
    setState(() {
      _format = saved['format'] ?? 'mp4';
      _quality = saved['quality'] ?? 'balanced';
      _customOutputDir = saved['outputDir'];
    });
  }

  String _computeOutputPath(String sourcePath, {Iterable<ConversionJob> extra = const []}) {
    final dir = _customOutputDir ?? p.dirname(sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath);
    var candidate = p.join(dir, '$baseName.$_format');
    var n = 1;
    bool taken(String path) =>
        File(path).existsSync() || _jobs.any((j) => j.outputPath == path) || extra.any((j) => j.outputPath == path);
    while (taken(candidate)) {
      candidate = p.join(dir, '$baseName ($n).$_format');
      n++;
    }
    return candidate;
  }

  void _refreshQueuedOutputPaths() {
    for (final job in _jobs) {
      if (job.status == JobStatus.queued) {
        job.outputPath = _computeOutputPath(job.sourcePath);
      }
    }
  }

  Future<void> _addPaths(List<String> paths) async {
    final added = <ConversionJob>[];
    for (final path in paths) {
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.directory) {
        final entries = await Directory(path).list(recursive: false).toList();
        for (final entity in entries) {
          if (entity is File) {
            added.add(ConversionJob(
              id: '${DateTime.now().microsecondsSinceEpoch}_${entity.path.hashCode}',
              sourcePath: entity.path,
              outputPath: _computeOutputPath(entity.path, extra: added),
            ));
          }
        }
      } else if (type == FileSystemEntityType.file) {
        added.add(ConversionJob(
          id: '${DateTime.now().microsecondsSinceEpoch}_${path.hashCode}',
          sourcePath: path,
          outputPath: _computeOutputPath(path, extra: added),
        ));
      }
    }
    if (added.isNotEmpty) {
      setState(() => _jobs.addAll(added));
    }
  }

  Future<void> _convertAll() async {
    if (_isConverting) return;
    setState(() => _isConverting = true);
    for (final job in _jobs.toList()) {
      if (job.status != JobStatus.queued) continue;
      await _convertOne(job);
    }
    if (mounted) setState(() => _isConverting = false);
  }

  Future<void> _convertOne(ConversionJob job) async {
    setState(() => job.status = JobStatus.converting);
    try {
      await _ffmpeg.convert(
        input: job.sourcePath,
        output: job.outputPath,
        qualityPreset: _quality,
        onStarted: (process) => job.process = process,
        onProgress: (progress) {
          if (mounted) setState(() => job.progress = progress);
        },
      );
      if (mounted) setState(() => job.status = JobStatus.done);
    } catch (_) {
      if (job.cancelRequested) {
        if (mounted) setState(() => job.status = JobStatus.canceled);
      } else {
        if (mounted) {
          setState(() {
            job.status = JobStatus.error;
            job.errorMessage = 'Could not convert this file - it may be corrupted or an unsupported format.';
          });
        }
      }
      try {
        final output = File(job.outputPath);
        if (output.existsSync()) output.deleteSync();
      } catch (_) {}
    }
  }

  void _cancelJob(ConversionJob job) {
    job.cancelRequested = true;
    job.process?.kill();
  }

  void _cancelAll() {
    for (final job in _jobs) {
      if (job.status == JobStatus.converting || job.status == JobStatus.queued) {
        job.cancelRequested = true;
        job.process?.kill();
        if (job.status == JobStatus.queued) {
          setState(() => job.status = JobStatus.canceled);
        }
      }
    }
  }

  void _removeJob(ConversionJob job) {
    setState(() => _jobs.remove(job));
  }

  void _clearFinished() {
    setState(() => _jobs.removeWhere((j) =>
        j.status == JobStatus.done || j.status == JobStatus.error || j.status == JobStatus.canceled));
  }

  Future<void> _revealInFolder(ConversionJob job) async {
    await Process.run('explorer', ['/select,"${job.outputPath}"']);
  }

  Future<void> _chooseOutputFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      setState(() => _customOutputDir = dir);
      _refreshQueuedOutputPaths();
      await _settings.saveOutputDir(dir);
    }
  }

  void _resetOutputFolder() {
    setState(() => _customOutputDir = null);
    _refreshQueuedOutputPaths();
    _settings.saveOutputDir(null);
  }

  void _onFormatChanged(String format) {
    setState(() => _format = format);
    _refreshQueuedOutputPaths();
    _settings.saveFormat(format);
  }

  void _onQualityChanged(String quality) {
    setState(() => _quality = quality);
    _settings.saveQuality(quality);
  }

  @override
  Widget build(BuildContext context) {
    final hasFinished =
        _jobs.any((j) => j.status == JobStatus.done || j.status == JobStatus.error || j.status == JobStatus.canceled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Converter'),
        actions: [
          if (hasFinished)
            TextButton(onPressed: _clearFinished, child: const Text('Clear finished')),
          const SizedBox(width: 8),
        ],
      ),
      body: DropTarget(
        onDragDone: (details) => _addPaths(details.files.map((f) => f.path).toList()),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _jobs.isEmpty ? Center(child: DropZone(onPathsSelected: _addPaths)) : _buildJobList(),
        ),
      ),
    );
  }

  Widget _buildJobList() {
    final queuedCount = _jobs.where((j) => j.status == JobStatus.queued).length;

    return Column(
      children: [
        _buildControlsRow(),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _jobs.length,
            itemBuilder: (context, index) {
              final job = _jobs[index];
              return JobTile(
                job: job,
                onRemove: () => _removeJob(job),
                onCancel: () => _cancelJob(job),
                onRevealInFolder: () => _revealInFolder(job),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                if (result != null) {
                  await _addPaths(result.paths.whereType<String>().toList());
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add more files'),
            ),
            const Spacer(),
            if (_isConverting)
              OutlinedButton.icon(
                onPressed: _cancelAll,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Cancel all'),
              )
            else
              ElevatedButton.icon(
                onPressed: queuedCount == 0 ? null : _convertAll,
                icon: const Icon(Icons.play_arrow),
                label: Text(queuedCount == 0 ? 'Convert all' : 'Convert all ($queuedCount)'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlsRow() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'mp4', label: Text('MP4')),
            ButtonSegment(value: 'mov', label: Text('MOV')),
          ],
          selected: {_format},
          onSelectionChanged: (selection) => _onFormatChanged(selection.first),
        ),
        DropdownMenu<String>(
          initialSelection: _quality,
          label: const Text('Quality'),
          onSelected: (value) {
            if (value != null) _onQualityChanged(value);
          },
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'fast', label: 'Fast'),
            DropdownMenuEntry(value: 'balanced', label: 'Balanced'),
            DropdownMenuEntry(value: 'best', label: 'Best quality'),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                _customOutputDir == null
                    ? 'Save next to each original file'
                    : 'Save to: ${_customOutputDir!}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            TextButton(onPressed: _chooseOutputFolder, child: const Text('Change')),
            if (_customOutputDir != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Reset to default folder',
                onPressed: _resetOutputFolder,
              ),
          ],
        ),
      ],
    );
  }
}
