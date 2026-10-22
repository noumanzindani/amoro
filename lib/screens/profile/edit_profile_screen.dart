import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../onboarding/question_input.dart';
import '../../onboarding/questions.dart';
import '../../providers/questions_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/ui.dart';

/// Every onboarding question, grouped by section. Tap one to edit it in a
/// bottom sheet with the same input used during signup.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final questions = context.watch<QuestionsProvider>().questions;
    final me = session.profile;
    if (me == null) return const Scaffold(body: Center(child: AppLoader()));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        children: [
          for (final group in QuestionGroup.values)
            if (questions.any(
              (q) => q.group == group && q.appliesTo(session.allAnswers),
            )) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  group.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final q in questions.where(
                (q) => q.group == group && q.appliesTo(session.allAnswers),
              ))
                ListTile(
                  title: Text(q.title),
                  subtitle: Text(
                    q.format(session.answerOf(q)) ??
                        (q.required ? 'Required' : 'Add'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(context, q, session.answerOf(q)),
                ),
            ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    ProfileQuestion q,
    dynamic current,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditSheet(question: q, initial: current),
  );
}

class _EditSheet extends StatefulWidget {
  final ProfileQuestion question;
  final dynamic initial;
  const _EditSheet({required this.question, required this.initial});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late dynamic _value = widget.initial;
  bool _saving = false;

  Future<void> _save() async {
    final q = widget.question;
    final value = normalizeAnswer(_value);
    final error = validateAnswer(q, value);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SessionProvider>().saveAnswer(q, value);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Couldn\'t save.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              q.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (q.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                q.subtitle!,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            QuestionInput(
              question: q,
              value: _value,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 20),
            AppButton(text: 'Save', loading: _saving, onPressed: _save),
            if (!q.required && widget.initial != null)
              TextButton(
                onPressed: _saving ? null : () => setState(() => _value = null),
                child: const Text('Clear answer'),
              ),
          ],
        ),
      ),
    );
  }
}
