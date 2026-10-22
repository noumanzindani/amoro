import 'package:flutter/material.dart';

import '../onboarding/questions.dart';

/// Placeholder; the full editor arrives in Task 7.
class QuestionEditorScreen extends StatelessWidget {
  final ProfileQuestion? existing;
  final List<ProfileQuestion> all;
  const QuestionEditorScreen({super.key, this.existing, required this.all});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(existing?.title ?? 'New question')));
}
