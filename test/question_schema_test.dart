import 'package:amore/onboarding/questions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProfileQuestion q(String id) =>
      defaultQuestions.firstWhere((q) => q.id == id);

  test('every default question round-trips through toMap/fromMap', () {
    for (final q in defaultQuestions) {
      final back = ProfileQuestion.fromMap(q.id, q.toMap())!;
      expect(back.toMap(), q.toMap(), reason: q.id);
      expect(back.type, q.type, reason: q.id);
      expect(back.private, q.private, reason: q.id);
      expect(back.showIf?.questionId, q.showIf?.questionId, reason: q.id);
    }
  });

  test('fromMap returns null for unknown type or missing title', () {
    expect(
      ProfileQuestion.fromMap('x', {
        'type': 'hologram',
        'group': 'about',
        'title': 'T',
      }),
      isNull,
    );
    expect(
      ProfileQuestion.fromMap('x', {'type': 'text', 'group': 'about'}),
      isNull,
    );
    expect(
      ProfileQuestion.fromMap('x', {
        'type': 'text',
        'group': 'nowhere',
        'title': 'T',
      }),
      isNull,
    );
  });

  test('ShowIf matches single and multi answers; missing answer is false', () {
    const s = ShowIf('gender', ['woman']);
    expect(s.matches({'gender': 'woman'}), isTrue);
    expect(s.matches({'gender': 'man'}), isFalse);
    expect(s.matches({}), isFalse);
    expect(
      const ShowIf('pets', ['dog']).matches({
        'pets': ['cat', 'dog'],
      }),
      isTrue,
    );
  });

  test('women-only defaults still apply only to women', () {
    expect(q('privatePhotos').appliesTo({'gender': 'woman'}), isTrue);
    expect(q('privatePhotos').appliesTo({'gender': 'nonbinary'}), isFalse);
  });

  test('scale template formats values', () {
    expect(q('attractionMen').format(7), '7 / 10');
    expect(q('firstSexualAwarenessAge').format(12), 'Age 12');
  });

  test('format ignores unknown option values', () {
    expect(q('pets').format(['dog', 'unicorn']), isNot(contains('unicorn')));
    expect(q('religion').format('gone'), isNull);
  });

  test('slugId makes unique camelCase ids', () {
    expect(slugId('Do you smoke weed?', {}), 'doYouSmokeWeed');
    expect(slugId('Pets', {'pets'}), 'pets2');
    expect(slugId('123 go', {}), 'q123Go');
    expect(slugId('!!!', {}), 'question');
    expect(slugId('a' * 50, {}).length, lessThanOrEqualTo(30));
  });

  test('validateQuestionDefinition catches broken drafts', () {
    Map<String, dynamic> d(Map<String, dynamic> m) => {
      'group': 'about',
      'title': 'T',
      ...m,
    };
    List<String> v(
      Map<String, dynamic> m, {
      String id = 'abc',
      Set<String> ids = const {},
    }) =>
        validateQuestionDefinition(d(m), id: id, isNew: true, existingIds: ids);
    const a = {'value': 'a', 'label': 'A'};

    expect(v({'type': 'single', 'options': []}), isNotEmpty);
    expect(v({'type': 'text'}, ids: {'abc'}), isNotEmpty);
    expect(v({'type': 'text'}, id: 'a_b'), isNotEmpty);
    expect(
      v({
        'type': 'multi',
        'minSelect': 3,
        'maxSelect': 2,
        'options': [a],
      }),
      isNotEmpty,
    );
    expect(
      v({'type': 'video', 'videoSeconds': 300, 'private': true}),
      isNotEmpty,
    );
    expect(
      v({'type': 'video', 'videoSeconds': 60, 'private': false}),
      isNotEmpty,
    );
    expect(v({'type': 'scale', 'scaleMin': 5, 'scaleMax': 5}), isNotEmpty);
    expect(
      v({
        'type': 'single',
        'options': [
          a,
          {'value': 'a', 'label': 'B'},
        ],
      }),
      isNotEmpty,
    );
    expect(
      v({
        'type': 'single',
        'options': [a],
      }),
      isEmpty,
    );
    expect(v({'type': 'video', 'videoSeconds': 60, 'private': true}), isEmpty);
  });

  test('every built-in question passes admin validation', () {
    for (final q in defaultQuestions) {
      expect(
        validateQuestionDefinition(
          q.toMap(),
          id: q.id,
          isNew: false,
          existingIds: const {},
        ),
        isEmpty,
        reason: q.id,
      );
    }
  });

  test('dependentsOf and genderValueMismatch', () {
    expect(
      dependentsOf('gender', defaultQuestions, value: 'woman').map((q) => q.id),
      containsAll(['privatePhotos', 'privateVideo']),
    );
    expect(dependentsOf('gender', defaultQuestions, value: 'man'), isEmpty);
    expect(genderValueMismatch(defaultQuestions), isEmpty);
  });
}
