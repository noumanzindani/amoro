import 'package:amore/onboarding/questions.dart';
import 'package:amore/providers/questions_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('effectiveQuestions falls back to defaults and drops inactive', () {
    expect(effectiveQuestions(null), defaultQuestions);
    expect(effectiveQuestions(const []), defaultQuestions);
    final a = ProfileQuestion.fromMap('a', {
      'type': 'text',
      'group': 'about',
      'title': 'A',
    })!;
    final b = ProfileQuestion.fromMap('b', {
      'type': 'text',
      'group': 'about',
      'title': 'B',
      'active': false,
    })!;
    expect(effectiveQuestions([a, b]).map((q) => q.id), ['a']);
  });

  test('every question hidden → built-in questions, never an empty flow', () {
    final b = ProfileQuestion.fromMap('b', {
      'type': 'text',
      'group': 'about',
      'title': 'B',
      'active': false,
    })!;
    expect(effectiveQuestions([b]), defaultQuestions);
  });

  group('resumeQuestionId', () {
    const qs = defaultQuestions;

    test('uses onboardingAt when it still applies', () {
      expect(
        resumeQuestionId(
          questions: qs,
          answers: {'gender': 'woman'},
          onboardingAt: 'privatePhotos',
        ),
        'privatePhotos',
      );
    });

    test('skips onboardingAt that no longer applies', () {
      expect(
        resumeQuestionId(
          questions: qs,
          answers: {'name': 'A', 'gender': 'man'},
          onboardingAt: 'privatePhotos',
        ),
        isNot('privatePhotos'),
      );
    });

    test('falls back to first unanswered applicable question', () {
      expect(
        resumeQuestionId(
          questions: qs,
          answers: {'name': 'Sara'},
          onboardingAt: 'deletedQuestion',
        ),
        'birthDate',
      );
    });

    test('all answered → last applicable', () {
      final all = {for (final q in qs) q.id: 'x', 'gender': 'man'};
      expect(
        resumeQuestionId(questions: qs, answers: all),
        qs.lastWhere((q) => q.appliesTo(all)).id,
      );
    });

    test('no questions → null', () {
      expect(resumeQuestionId(questions: const [], answers: const {}), isNull);
    });
  });
}
