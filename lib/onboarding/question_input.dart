import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
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
          max: question.maxSelect ?? 6,
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
  final List<String> urls;
  final int max;
  final ValueChanged<dynamic> onChanged;
  const _PhotosAnswer({
    required this.urls,
    required this.max,
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
      final url = await storage.uploadPhoto(uid, File(picked.path));
      widget.onChanged([...widget.urls, url]);
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
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3 / 4,
      children: [
        for (final url in widget.urls)
          Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _remove(url),
                ),
              ),
            ],
          ),
        if (widget.urls.length < widget.max)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _uploading ? null : _add,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant, width: 2),
              ),
              child: Center(
                child: _uploading
                    ? const AppLoader()
                    : Icon(
                        Icons.add_a_photo_outlined,
                        color: scheme.primary,
                        size: 32,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
