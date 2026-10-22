import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../onboarding/question_input.dart';
import '../../onboarding/questions.dart';
import '../../providers/questions_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/ui.dart';

/// One question per page. Each answer is saved as the user moves on, along
/// with `onboardingAt` (the next question's id), so quitting midway resumes
/// at the same question even if the admin reorders questions meanwhile.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final questions = context.watch<QuestionsProvider>();
    if (!questions.loaded) {
      return const Scaffold(body: Center(child: AppLoader()));
    }
    return _OnboardingFlow(questions: questions.questions);
  }
}

class _OnboardingFlow extends StatefulWidget {
  final List<ProfileQuestion> questions;
  const _OnboardingFlow({required this.questions});

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  late final SessionProvider _session = context.read<SessionProvider>();
  late final Map<String, dynamic> _answers = _session.allAnswers;
  // A snapshot: admin edits made while someone is mid-flow apply next time.
  late final List<ProfileQuestion> _qs = List.of(widget.questions);
  late int _step = _resumeStep();
  late final PageController _pages = PageController(initialPage: _step);
  bool _saving = false;

  ProfileQuestion get _question => _qs[_step];
  bool get _isLast => _nextFrom(_step) == null;

  bool _applies(int i) => _qs[i].appliesTo(_answers);

  /// Indices of the questions this user is asked (e.g. women-only steps
  /// drop out for everyone else).
  List<int> get _flow => [
    for (var i = 0; i < _qs.length; i++)
      if (_applies(i)) i,
  ];

  int? _nextFrom(int i) {
    for (var j = i + 1; j < _qs.length; j++) {
      if (_applies(j)) return j;
    }
    return null;
  }

  int? _prevFrom(int i) {
    for (var j = i - 1; j >= 0; j--) {
      if (_applies(j)) return j;
    }
    return null;
  }

  int _resumeStep() {
    final id = resumeQuestionId(
      questions: _qs,
      answers: _answers,
      onboardingAt: _session.profile!.onboardingAt,
    );
    return id == null ? 0 : _qs.indexWhere((q) => q.id == id);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next({bool skip = false}) async {
    final q = _question;
    final value = skip ? null : normalizeAnswer(_answers[q.id]);
    if (!skip) {
      final error = validateAnswer(q, value);
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    // Computed before saving: this answer can change which questions apply.
    _answers[q.id] = value;
    final next = _nextFrom(_step);
    setState(() => _saving = true);
    try {
      await _session.saveAnswer(
        q,
        value,
        extra: {
          'onboardingAt': next == null ? null : _qs[next].id,
          'onboardingStep': next ?? _step + 1, // read by older app builds
          if (next == null) 'onboardingComplete': true,
        },
      );
      // On the last step the router takes over and leaves this screen.
      if (next != null && mounted) _goTo(next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t save. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _question;
    final prev = _prevFrom(_step);
    final flow = _flow;
    return Scaffold(
      appBar: AppBar(
        leading: prev != null
            ? CircleBackButton(onPressed: _saving ? null : () => _goTo(prev))
            : null,
        title: Text(q.group.label),
        actions: [
          if (!q.required)
            TextButton(
              onPressed: _saving ? null : () => _next(skip: true),
              child: const Text('Skip'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (flow.indexOf(_step) + 1) / flow.length,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _qs.length,
        itemBuilder: (context, i) {
          final page = _qs[i];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (page.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    page.subtitle!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                QuestionInput(
                  question: page,
                  value: _answers[page.id],
                  onChanged: (v) => setState(() => _answers[page.id] = v),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: AppButton(
            text: _isLast ? 'Finish' : 'Next',
            loading: _saving,
            onPressed: _next,
          ),
        ),
      ),
    );
  }
}
