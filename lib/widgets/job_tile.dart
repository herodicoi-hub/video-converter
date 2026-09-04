import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/conversion_job.dart';

class JobTile extends StatelessWidget {
  final ConversionJob job;
  final VoidCallback onRemove;
  final VoidCallback onCancel;
  final VoidCallback onRevealInFolder;

  const JobTile({
    super.key,
    required this.job,
    required this.onRemove,
    required this.onCancel,
    required this.onRevealInFolder,
  });

  Icon _statusIcon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (job.status) {
      case JobStatus.queued:
        return Icon(Icons.schedule, color: scheme.outline);
      case JobStatus.converting:
        return Icon(Icons.autorenew, color: scheme.primary);
      case JobStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case JobStatus.error:
        return Icon(Icons.error, color: scheme.error);
      case JobStatus.canceled:
        return Icon(Icons.cancel, color: scheme.outline);
    }
  }

  String _subtitle() {
    switch (job.status) {
      case JobStatus.queued:
        return 'Waiting - will save as ${job.outputFileName}';
      case JobStatus.converting:
        return 'Converting... ${(job.progress * 100).toStringAsFixed(0)}%';
      case JobStatus.done:
        return 'Saved as ${job.outputFileName}';
      case JobStatus.error:
        return job.errorMessage ?? 'Conversion failed';
      case JobStatus.canceled:
        return 'Canceled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _statusIcon(context),
        title: Text(job.fileName, overflow: TextOverflow.ellipsis),
        subtitle: job.status == JobStatus.converting
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: job.progress),
                    const SizedBox(height: 4),
                    Text(_subtitle()),
                  ],
                ),
              )
            : Text(
                _subtitle(),
                overflow: TextOverflow.ellipsis,
                style: job.status == JobStatus.error
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    switch (job.status) {
      case JobStatus.converting:
        return IconButton(
          icon: const Icon(Icons.stop_circle_outlined),
          tooltip: 'Cancel',
          onPressed: onCancel,
        );
      case JobStatus.done:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Play',
              onPressed: () => launchUrl(Uri.file(job.outputPath)),
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Show in folder',
              onPressed: onRevealInFolder,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove from list',
              onPressed: onRemove,
            ),
          ],
        );
      case JobStatus.queued:
      case JobStatus.error:
      case JobStatus.canceled:
        return IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Remove from list',
          onPressed: onRemove,
        );
    }
  }
}
