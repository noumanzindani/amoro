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
  late final Map<String, dynamic> _answers = {..._session.profile!.data};
  late int _step = _session.profile!.onboardingStep.clamp(
    0,
    profileQuestions.length - 1,
  );
  late final PageController _pages = PageController(initialPage: _step);
  bool _saving = false;

  ProfileQuestion get _question => profileQuestions[_step];
  bool get _isLast => _step == profileQuestions.length - 1;

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
      await _session.updateProfile({
        q.id: value,
        'onboardingStep': _step + 1,
        if (_isLast) 'onboardingComplete': true,
      });
      // On the last step the router takes over and leaves this screen.
      if (!_isLast && mounted) _goTo(_step + 1);
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
    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? CircleBackButton(
                onPressed: _saving ? null : () => _goTo(_step - 1),
              )
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
            value: (_step + 1) / profileQuestions.length,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: profileQuestions.length,
        itemBuilder: (context, i) {
          final page = profileQuestions[i];
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
