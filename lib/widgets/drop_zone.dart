import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DropZone extends StatefulWidget {
  final void Function(List<String> paths) onPathsSelected;
  const DropZone({super.key, required this.onPathsSelected});

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _hovering = false;

  Future<void> _browseFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.paths.isNotEmpty) {
      widget.onPathsSelected(result.paths.whereType<String>().toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) {
        setState(() => _hovering = false);
        widget.onPathsSelected(details.files.map((f) => f.path).toList());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: Border.all(color: _hovering ? scheme.primary : scheme.outline, width: 2),
          borderRadius: BorderRadius.circular(16),
          color: _hovering ? scheme.primary.withOpacity(0.08) : null,
        ),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_file_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Drag & drop video files here',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('Any video format - .avi, .mkv, .wmv, .webm, and more', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _browseFiles,
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse files'),
            ),
          ],
        ),
      ),
    );
  }
}
