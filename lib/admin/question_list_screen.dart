import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../onboarding/questions.dart';
import '../services/question_repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'question_editor_screen.dart';

/// Every question in order: drag to reorder, switch to show/hide, and edit,
/// duplicate or delete from the menu.
class QuestionListScreen extends StatefulWidget {
  const QuestionListScreen({super.key});

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  final _repo = QuestionRepository();
  late final _stream = _repo.watchAll();

  /// Shown instead of the stream's order while a reorder is being saved.
  List<ProfileQuestion>? _pendingOrder;

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _guard(Future<void> Function() action, String failed) async {
    try {
      await action();
    } catch (e) {
      _say('$failed ($e)');
    }
  }

  Future<void> _import() => _guard(() async {
    final n = await _repo.importDefaults();
    _say(n == 0 ? 'Questions already exist.' : 'Imported $n questions.');
  }, 'Import failed');

  Future<void> _reorder(List<ProfileQuestion> all, int from, int to) async {
    final list = [...all];
    if (to > from) to--;
    list.insert(to, list.removeAt(from));
    setState(() => _pendingOrder = list);
    await _guard(
      () => _repo.reorder([for (final q in list) q.id]),
      'Reorder failed',
    );
    if (mounted) setState(() => _pendingOrder = null);
  }

  Future<void> _setActive(ProfileQuestion q, bool active) async {
    if (!active &&
        q.system &&
        !await _confirm(
          'Hide a core question?',
          '"${q.title}" is used by sign-up and matching. Hiding it can '
              'break them for new users.',
          'Hide',
        )) {
      return;
    }
    await _guard(
      () => _repo.upsert(q.id, {...q.toMap(), 'active': active}),
      'Couldn\'t save',
    );
  }

  Future<void> _duplicate(ProfileQuestion q, List<ProfileQuestion> all) {
    final id = slugId('${q.id} copy', {for (final x in all) x.id});
    return _guard(
      () => _repo.upsert(id, {
        ...q.toMap(),
        'title': '${q.title} (copy)',
        'active': false,
        'order': q.order + 1,
      }),
      'Couldn\'t duplicate',
    );
  }

  Future<void> _delete(ProfileQuestion q, List<ProfileQuestion> all) async {
    final dependents = dependentsOf(q.id, all);
    final warning = dependents.isEmpty
        ? ''
        : '\n\nThese questions are only shown based on its answer and will '
              'stop appearing: ${dependents.map((d) => d.title).join(', ')}.';
    if (!await _confirm(
      'Delete "${q.title}"?',
      'Users\' saved answers are kept, but the question is no longer asked.'
          '$warning',
      'Delete',
    )) {
      return;
    }
    await _guard(() => _repo.delete(q.id), 'Couldn\'t delete');
  }

  void _open(ProfileQuestion? q, List<ProfileQuestion> all) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => QuestionEditorScreen(existing: q, all: all),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return StreamBuilder<List<ProfileQuestion>>(
      stream: _stream,
      builder: (context, snap) {
        final all = _pendingOrder ?? snap.data;
        final mismatch = all == null
            ? const <String>{}
            : genderValueMismatch(all);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Questions'),
            actions: [
              Center(
                child: Text(
                  email,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: FirebaseAuth.instance.signOut,
                child: const Text('Sign out'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: all == null || all.isEmpty
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('New question'),
                  onPressed: () => _open(null, all),
                ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: switch (all) {
                _ when snap.hasError => Center(
                  child: Text('Couldn\'t load questions: ${snap.error}'),
                ),
                null => const Center(child: AppLoader()),
                [] => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No questions yet. Start from the app\'s built-in set.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 280,
                        child: AppButton(
                          text: 'Import built-in questions',
                          onPressed: _import,
                        ),
                      ),
                    ],
                  ),
                ),
                _ => Column(
                  children: [
                    if (mismatch.isNotEmpty)
                      MaterialBanner(
                        content: Text(
                          'Gender and "Interested in" should offer the same '
                          'options; matching compares them. Only in one: '
                          '${mismatch.join(', ')}.',
                        ),
                        actions: const [SizedBox.shrink()],
                      ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        buildDefaultDragHandles: false,
                        itemCount: all.length,
                        onReorder: (from, to) => _reorder(all, from, to),
                        itemBuilder: (context, i) {
                          final q = all[i];
                          return _QuestionTile(
                            key: ValueKey(q.id),
                            index: i,
                            question: q,
                            all: all,
                            onEdit: () => _open(q, all),
                            onActive: (v) => _setActive(q, v),
                            onDuplicate: () => _duplicate(q, all),
                            onDelete: q.system ? null : () => _delete(q, all),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final int index;
  final ProfileQuestion question;
  final List<ProfileQuestion> all;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActive;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  const _QuestionTile({
    super.key,
    required this.index,
    required this.question,
    required this.all,
    required this.onEdit,
    required this.onActive,
    required this.onDuplicate,
    required this.onDelete,
  });

  String? _conditionText() {
    final s = question.showIf;
    if (s == null) return null;
    final source = all.where((q) => q.id == s.questionId).firstOrNull;
    final labels = [
      for (final v in s.values)
        source?.options.where((o) => o.value == v).firstOrNull?.label ?? v,
    ];
    return 'If ${source?.title ?? s.questionId} = ${labels.join(' / ')}';
  }

  @override
  Widget build(BuildContext context) {
    final q = question;
    final condition = _conditionText();
    return Opacity(
      opacity: q.active ? 1 : 0.5,
      child: Card(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onEdit,
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator, color: AppColors.muted),
          ),
          title: Text(q.title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge(q.id, muted: true),
                _Badge(q.type.name),
                _Badge(q.group.label),
                if (q.required) const _Badge('Required'),
                if (q.private) const _Badge('Private', icon: Icons.lock),
                if (q.hasImageOptions)
                  const _Badge('Pictures', icon: Icons.image),
                if (q.system) const _Badge('Core', icon: Icons.shield_outlined),
                if (condition != null)
                  _Badge(condition, icon: Icons.call_split),
                if (!q.active)
                  const _Badge('Hidden', icon: Icons.visibility_off),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: q.active ? 'Shown in the app' : 'Hidden from the app',
                child: Switch(value: q.active, onChanged: onActive),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => switch (v) {
                  'edit' => onEdit(),
                  'duplicate' => onDuplicate(),
                  _ => onDelete?.call(),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: onDelete != null,
                    child: Text(
                      onDelete == null ? 'Delete (core question)' : 'Delete',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool muted;
  const _Badge(this.text, {this.icon, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? Colors.transparent : AppColors.surfaceHigh,
        border: muted ? Border.all(color: AppColors.outline) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.muted),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
