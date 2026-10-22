import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../onboarding/question_input.dart';
import '../../onboarding/questions.dart';
import '../../providers/session_provider.dart';
import '../../widgets/ui.dart';

/// One question per page. Each answer is saved as the user moves on, along
/// with `onboardingStep`, so quitting midway resumes at the same question.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final SessionProvider _session = context.read<SessionProvider>();
  late final Map<String, dynamic> _answers = _session.allAnswers;
  late int _step = _resumeStep();
  late final PageController _pages = PageController(initialPage: _step);
  bool _saving = false;

  ProfileQuestion get _question => defaultQuestions[_step];
  bool get _isLast => _nextFrom(_step) == null;

  bool _applies(int i) => defaultQuestions[i].appliesTo(_answers);

  /// Indices of the questions this user is asked (e.g. women-only steps
  /// drop out for everyone else).
  List<int> get _flow => [
    for (var i = 0; i < defaultQuestions.length; i++)
      if (_applies(i)) i,
  ];

  int? _nextFrom(int i) {
    for (var j = i + 1; j < defaultQuestions.length; j++) {
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

  /// The saved step, moved onto a question this user is actually asked.
  int _resumeStep() {
    final saved = _session.profile!.onboardingStep.clamp(
      0,
      defaultQuestions.length - 1,
    );
    if (_applies(saved)) return saved;
    return _nextFrom(saved) ?? _prevFrom(saved) ?? 0;
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
    setState(() => _saving = true);
    try {
      await _session.saveAnswer(
        q,
        value,
        extra: {
          'onboardingStep': _nextFrom(_step) ?? _step + 1,
          if (_isLast) 'onboardingComplete': true,
        },
      );
      // On the last step the router takes over and leaves this screen.
      final next = _nextFrom(_step);
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
        itemCount: defaultQuestions.length,
        itemBuilder: (context, i) {
          final page = defaultQuestions[i];
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
