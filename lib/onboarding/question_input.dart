import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../backend.dart';
import '../models/message.dart';
import '../providers/session_provider.dart';
import '../screens/chat/media_viewer_screen.dart';
import '../services/storage_service.dart';
import 'questions.dart';
import '../widgets/ui.dart';

/// The answer control for any [ProfileQuestion]. Stateless about the value:
/// the parent owns it and receives changes through [onChanged].
class QuestionInput extends StatelessWidget {
  final ProfileQuestion question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const QuestionInput({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuestionType.text:
      case QuestionType.longText:
        return _TextAnswer(
          question: question,
          value: value as String?,
          onChanged: onChanged,
        );
      case QuestionType.date:
        return _DateAnswer(value: value as Timestamp?, onChanged: onChanged);
      case QuestionType.height:
        return _HeightAnswer(value: value as int?, onChanged: onChanged);
      case QuestionType.scale:
        return _ScaleAnswer(
          question: question,
          value: value as int?,
          onChanged: onChanged,
        );
      case QuestionType.single:
        return _ChoiceAnswer(
          question: question,
          selected: value == null ? const [] : [value as String],
          onChanged: (list) => onChanged(list.isEmpty ? null : list.first),
          multi: false,
        );
      case QuestionType.multi:
        return _ChoiceAnswer(
          question: question,
          selected: List<String>.from(value ?? const []),
          onChanged: onChanged,
          multi: true,
        );
      case QuestionType.photos:
        return _PhotosAnswer(
          urls: List<String>.from(value ?? const []),
          max: question.maxSelect ?? 1,
          private: question.private,
          onChanged: onChanged,
        );
      case QuestionType.video:
        return _VideoAnswer(
          path: value as String?,
          length: question.videoLength ?? const Duration(seconds: 30),
          onChanged: onChanged,
        );
    }
  }
}

class _TextAnswer extends StatefulWidget {
  final ProfileQuestion question;
  final String? value;
  final ValueChanged<dynamic> onChanged;
  const _TextAnswer({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final _controller = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final long = widget.question.type == QuestionType.longText;
    return TextField(
      controller: _controller,
      autofocus: true,
      maxLength: widget.question.maxLength,
      minLines: long ? 4 : 1,
      maxLines: long ? 8 : 1,
      textCapitalization: long
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      onChanged: widget.onChanged,
    );
  }
}

class _DateAnswer extends StatelessWidget {
  final Timestamp? value;
  final ValueChanged<dynamic> onChanged;
  const _DateAnswer({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final date = value?.toDate();
    final now = DateTime.now();
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      icon: const Icon(Icons.cake_outlined),
      label: Text(
        date == null ? 'Choose date' : '${date.day}/${date.month}/${date.year}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime(now.year - 25, now.month, now.day),
          firstDate: DateTime(now.year - 100),
          lastDate: now,
          initialDatePickerMode: DatePickerMode.year,
        );
        if (picked != null) onChanged(Timestamp.fromDate(picked));
      },
    );
  }
}

class _HeightAnswer extends StatelessWidget {
  final int? value;
  final ValueChanged<dynamic> onChanged;
  const _HeightAnswer({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cm = value ?? 170;
    return Column(
      children: [
        Text(
          value == null ? 'Slide to set' : formatHeight(cm),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Slider(
          value: cm.toDouble(),
          min: 120,
          max: 220,
          divisions: 100,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _ScaleAnswer extends StatelessWidget {
  final ProfileQuestion question;
  final int? value;
  final ValueChanged<dynamic> onChanged;
  const _ScaleAnswer({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;
    final v = value ?? ((q.scaleMin + q.scaleMax) / 2).round();
    final ends = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Text(
          value == null ? 'Slide to set' : q.format(v)!,
          style: theme.textTheme.headlineSmall,
        ),
        Slider(
          value: v.toDouble(),
          min: q.scaleMin.toDouble(),
          max: q.scaleMax.toDouble(),
          divisions: q.scaleMax - q.scaleMin,
          label: q.format(v),
          onChanged: (x) => onChanged(x.round()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(q.lowLabel ?? '${q.scaleMin}', style: ends),
              Text(q.highLabel ?? '${q.scaleMax}', style: ends),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceAnswer extends StatelessWidget {
  final ProfileQuestion question;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool multi;
  const _ChoiceAnswer({
    required this.question,
    required this.selected,
    required this.onChanged,
    required this.multi,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in question.options)
          FilterChip(
            label: Text(o.display),
            selected: selected.contains(o.value),
            showCheckmark: multi,
            onSelected: (on) {
              if (!multi) return onChanged(on ? [o.value] : const []);
              final next = [...selected];
              on ? next.add(o.value) : next.remove(o.value);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _PhotosAnswer extends StatefulWidget {
  /// Download URLs for public photos; Storage paths for private ones.
  final List<String> urls;
  final int max;
  final bool private;
  final ValueChanged<dynamic> onChanged;
  const _PhotosAnswer({
    required this.urls,
    required this.max,
    required this.private,
    required this.onChanged,
  });

  @override
  State<_PhotosAnswer> createState() => _PhotosAnswerState();
}

class _PhotosAnswerState extends State<_PhotosAnswer> {
  bool _uploading = false;

  Future<void> _add() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final uid = context.read<SessionProvider>().uid!;
    final storage = context.read<StorageService>();
    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final ref = widget.private
          ? await storage.uploadPrivatePhoto(uid, file)
          : await storage.uploadPhoto(uid, file);
      widget.onChanged([...widget.urls, ref]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // The file isn't deleted from Storage here: in Edit Profile the user may
  // still cancel, and the profile would then point at a missing photo.
  void _remove(String url) =>
      widget.onChanged(widget.urls.where((u) => u != url).toList());

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final slots = [
      for (final url in urls)
        _PhotoSlot(
          image: widget.private
              ? _StorageImage(path: url)
              : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          onRemove: () => _remove(url),
        ),
      // Photos fill in order, so only the first empty slot is tappable.
      for (var i = urls.length; i < widget.max; i++)
        _EmptyPhotoSlot(
          uploading: i == urls.length && _uploading,
          onTap: i == urls.length && !_uploading ? _add : null,
        ),
    ];

    if (widget.max == 1) {
      return Center(
        child: SizedBox(
          width: 220,
          child: AspectRatio(aspectRatio: 3 / 4, child: slots.first),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3 / 4,
      children: slots,
    );
  }
}

/// A private photo, downloaded through the SDK so Storage rules apply.
class _StorageImage extends StatefulWidget {
  final String path;
  const _StorageImage({required this.path});

  @override
  State<_StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<_StorageImage> {
  late final Future<Uint8List?> _bytes = Backend.storage
      .ref(widget.path)
      .getData(10 * 1024 * 1024);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, snap) {
      final bytes = snap.data;
      if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
      if (snap.hasError) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
      return const Center(child: AppLoader());
    },
  );
}

class _PhotoSlot extends StatelessWidget {
  final Widget image;
  final VoidCallback onRemove;
  const _PhotoSlot({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}

class _EmptyPhotoSlot extends StatelessWidget {
  final bool uploading;
  final VoidCallback? onTap;
  const _EmptyPhotoSlot({required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = onTap != null || uploading;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant, width: 2),
        ),
        child: Center(
          child: uploading
              ? const AppLoader()
              : Icon(
                  Icons.add_a_photo_outlined,
                  color: active ? scheme.primary : scheme.outlineVariant,
                  size: 32,
                ),
        ),
      ),
    );
  }
}

/// Records a private video of exactly [length] with the camera (never the
/// gallery). The camera stops itself at [length]; recordings that come back
/// noticeably shorter or longer are rejected.
class _VideoAnswer extends StatefulWidget {
  final String? path;
  final Duration length;
  final ValueChanged<dynamic> onChanged;
  const _VideoAnswer({
    required this.path,
    required this.length,
    required this.onChanged,
  });

  // Cameras stop a few frames either side of the limit.
  static const tolerance = Duration(seconds: 1);

  @override
  State<_VideoAnswer> createState() => _VideoAnswerState();
}

class _VideoAnswerState extends State<_VideoAnswer> {
  String? _busy; // what's happening, shown while recording is processed
  double? _progress; // 0–1 while uploading/downloading, null otherwise

  void _idle() => setState(() {
    _busy = null;
    _progress = null;
  });

  void _onProgress(double p) {
    if (mounted) setState(() => _progress = p);
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<Duration> _durationOf(File file) async {
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize();
      return c.value.duration;
    } finally {
      await c.dispose();
    }
  }

  Future<void> _record() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxDuration: widget.length,
    );
    if (picked == null || !mounted) return;
    final uid = context.read<SessionProvider>().uid!;
    final storage = context.read<StorageService>();
    final file = File(picked.path);
    setState(() => _busy = 'Checking video…');
    try {
      final d = await _durationOf(file);
      final min = widget.length - _VideoAnswer.tolerance;
      final max = widget.length + _VideoAnswer.tolerance;
      final wanted = formatVideoLength(widget.length);
      if (d < min) {
        return _say(
          'Your video was ${d.inSeconds}s. Please record the full $wanted.',
        );
      }
      if (d > max) return _say('Please keep your video to $wanted.');
      if (mounted) setState(() => _busy = 'Uploading video…');
      widget.onChanged(
        await storage.uploadPrivateVideo(uid, file, onProgress: _onProgress),
      );
    } catch (e) {
      if (mounted) _say('Upload failed. Try again.');
    } finally {
      if (mounted) _idle();
    }
  }

  Future<void> _watch(String path) async {
    final storage = context.read<StorageService>();
    setState(() => _busy = 'Loading video…');
    try {
      final file = await storage.downloadPrivate(path, onProgress: _onProgress);
      if (!mounted) return;
      _idle();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MediaViewerScreen(file: file, type: MessageType.video),
        ),
      );
    } catch (e) {
      if (mounted) _say('Couldn\'t load the video.');
    } finally {
      if (mounted) _idle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _busy;
    final path = widget.path;
    if (busy != null) {
      final progress = _progress;
      if (progress == null) {
        return Column(
          children: [
            const SizedBox(height: 24),
            const AppLoader(),
            const SizedBox(height: 12),
            Text(busy),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text(busy)),
              Text(
                '${(progress * 100).floor()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
        ],
      );
    }
    if (path == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Record video'),
            onPressed: _record,
          ),
          const SizedBox(height: 8),
          Text(
            'The camera stops by itself after '
            '${formatVideoLength(widget.length)}.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.check_circle, color: scheme.primary),
          title: const Text('Video recorded'),
          trailing: TextButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Watch'),
            onPressed: () => _watch(path),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.replay),
          label: const Text('Record again'),
          onPressed: _record,
        ),
      ],
    );
  }
}
