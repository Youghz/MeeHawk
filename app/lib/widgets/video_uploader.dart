import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/video_provider.dart';
import '../theme.dart';

class VideoUploader extends ConsumerStatefulWidget {
  const VideoUploader({super.key});

  @override
  ConsumerState<VideoUploader> createState() => _VideoUploaderState();
}

class _VideoUploaderState extends ConsumerState<VideoUploader> {
  final _ytController = TextEditingController();
  bool _uploading = false;
  String _statusText = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _uploading = true;
      _statusText = 'Uploading...';
    });
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.uploadVideo(file.path!, file.name);
      ref.read(selectedVideoIdProvider.notifier).select(resp['video_id'] as String);
      ref.read(videosProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() { _uploading = false; _statusText = ''; });
    }
  }

  Future<void> _downloadYoutube() async {
    final url = _ytController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _uploading = true;
      _statusText = 'Downloading from YouTube...';
    });
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.uploadYoutube(url);
      ref.read(selectedVideoIdProvider.notifier).select(resp['video_id'] as String);
      ref.read(videosProvider.notifier).refresh();
      _ytController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('YouTube download failed: $e')));
      }
    } finally {
      if (mounted) setState(() { _uploading = false; _statusText = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADD VIDEO',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          // File picker
          GestureDetector(
            onTap: _uploading ? null : _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: _uploading
                    ? Text(_statusText,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    : const Text('Click to upload video',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // YouTube URL
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _ytController,
                    enabled: !_uploading,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'YouTube URL',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: (_) => _downloadYoutube(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _downloadYoutube,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('DL', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ytController.dispose();
    super.dispose();
  }
}
