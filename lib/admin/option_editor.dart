import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../backend.dart';
import '../onboarding/questions.dart';
import '../theme.dart';

/// Edits a choice question's options. Each option's value is generated from
/// its label once, when added, and never changes afterwards (saved answers
/// refer to it); label, emoji and picture can be edited freely.
class OptionEditor extends StatefulWidget {
  final String questionId;
  final List<Map<String, dynamic>> options;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  /// Asked before removing an option; return false to keep it.
  final Future<bool> Function(String value) confirmRemove;

  const OptionEditor({
    super.key,
    required this.questionId,
    required this.options,
    required this.onChanged,
    required this.confirmRemove,
  });

  @override
  State<OptionEditor> createState() => _OptionEditorState();
}

class _OptionEditorState extends State<OptionEditor> {
  final _newLabel = TextEditingController();
  String? _uploading; // value of the option whose picture is uploading

  @override
  void dispose() {
    _newLabel.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _opts => widget.options;

  void _set(int i, String key, String? v) {
    final next = [..._opts];
    final o = {...next[i]};
    v == null || v.isEmpty ? o.remove(key) : o[key] = v;
    next[i] = o;
    widget.onChanged(next);
  }

  void _add() {
    final label = _newLabel.text.trim();
    if (label.isEmpty) return;
    final value = slugId(label, {for (final o in _opts) o['value'] as String});
    widget.onChanged([
      ..._opts,
      {'value': value, 'label': label},
    ]);
    _newLabel.clear();
  }

  Future<void> _remove(int i) async {
    if (!await widget.confirmRemove(_opts[i]['value'] as String)) return;
    widget.onChanged([..._opts]..removeAt(i));
  }

  Future<void> _pickImage(int i) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    final value = _opts[i]['value'] as String;
    setState(() => _uploading = value);
    try {
      final bytes = await picked.readAsBytes();
      final ref = Backend.storage.ref(
        'amore_question_media/${widget.questionId}/'
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putData(
        bytes,
        SettableMetadata(contentType: picked.mimeType ?? 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      final at = _opts.indexWhere((o) => o['value'] == value);
      if (at >= 0) _set(at, 'imageUrl', url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Picture upload failed ($e)')));
      }
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _opts.length,
          onReorder: (from, to) {
            if (to > from) to--;
            final next = [..._opts];
            next.insert(to, next.removeAt(from));
            widget.onChanged(next);
          },
          itemBuilder: (context, i) {
            final o = _opts[i];
            final value = o['value'] as String;
            final url = o['imageUrl'] as String?;
            return Padding(
              key: ValueKey(value),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Icon(
                      Icons.drag_indicator,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      initialValue: o['emoji'] as String?,
                      decoration: const InputDecoration(hintText: 'Emoji'),
                      onChanged: (v) => _set(i, 'emoji', v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: o['label'] as String?,
                      decoration: InputDecoration(
                        hintText: 'Label',
                        helperText: 'value: $value',
                      ),
                      onChanged: (v) => _set(i, 'label', v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ImageButton(
                    url: url,
                    uploading: _uploading == value,
                    onPick: _uploading == null ? () => _pickImage(i) : null,
                    onClear: url == null
                        ? null
                        : () => _set(i, 'imageUrl', null),
                  ),
                  IconButton(
                    tooltip: 'Remove option',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(i),
                  ),
                ],
              ),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newLabel,
                decoration: const InputDecoration(hintText: 'New option label'),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add option'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImageButton extends StatelessWidget {
  final String? url;
  final bool uploading;
  final VoidCallback? onPick;
  final VoidCallback? onClear;
  const _ImageButton({
    required this.url,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: uploading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : url == null
                ? const Tooltip(
                    message: 'Add a picture',
                    child: Icon(Icons.add_photo_alternate_outlined),
                  )
                : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          ),
        ),
        if (onClear != null)
          IconButton(
            tooltip: 'Remove picture',
            icon: const Icon(Icons.hide_image_outlined, size: 20),
            onPressed: onClear,
          ),
      ],
    );
  }
}
