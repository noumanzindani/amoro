import 'package:amore/onboarding/questions.dart';
import 'package:amore/widgets/profile_card.dart';
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
    // As imported: order = index * 10.
    final imported = [
      for (var i = 0; i < defaultQuestions.length; i++)
        ProfileQuestion.fromMap(defaultQuestions[i].id, {
          ...defaultQuestions[i].toMap(),
          'order': i * 10,
        })!,
    ];
    for (final q in imported) {
      expect(
        validateQuestionDefinition(
          q.toMap(),
          id: q.id,
          isNew: false,
          existingIds: const {},
          others: imported,
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

  group('profile display', () {
    ProfileQuestion custom(String id, Map<String, dynamic> m) =>
        ProfileQuestion.fromMap(id, {'group': 'about', 'title': id, ...m})!;

    test('showsAsChip only for short public answers', () {
      for (final id in [
        'name',
        'birthDate',
        'gender',
        'interestedIn',
        'bio',
        'photoUrls',
        'interests',
        'privatePhotos',
        'attractionMen',
      ]) {
        expect(showsAsChip(q(id)), isFalse, reason: id);
      }
      expect(showsAsChip(q('lookingFor')), isTrue);
      expect(showsAsChip(custom('story', {'type': 'longText'})), isFalse);
      expect(showsAsChip(custom('pics', {'type': 'photos'})), isFalse);
      expect(
        showsAsChip(custom('clip', {'type': 'video', 'private': true})),
        isFalse,
      );
    });

    test('profileSections lists public long text and photo questions', () {
      final qs = [
        q('bio'),
        q('photoUrls'),
        custom('story', {'type': 'longText'}),
        custom('secret', {'type': 'longText', 'private': true}),
        custom('pics', {'type': 'photos', 'maxSelect': 3}),
        q('privatePhotos'),
      ];
      expect(profileSections(qs).map((q) => q.id), ['story', 'pics']);
    });
  });

  group('review fixes', () {
    test('fromMap tolerates wrongly typed fields instead of throwing', () {
      final q = ProfileQuestion.fromMap('x', {
        'type': 'single',
        'group': 'about',
        'title': 'T',
        'order': '5',
        'options': {'a': 1},
        'subtitle': 3,
      });
      expect(q, isNotNull);
      expect(q!.order, 0);
      expect(q.options, isEmpty);
      final o = ProfileQuestion.fromMap('y', {
        'type': 'single',
        'group': 'about',
        'title': 'T',
        'options': [
          {'value': 'a', 'label': 'A', 'emoji': 7, 'imageUrl': false},
        ],
      })!;
      expect(o.options.single.emoji, isNull);
      expect(o.options.single.imageUrl, isNull);
    });

    test('reserved field names cannot be question ids', () {
      for (final id in [
        'fcmTokens',
        'onboardingAt',
        'onboardingComplete',
        'onboardingStep',
        'createdAt',
        'updatedAt',
        'seed',
      ]) {
        expect(
          validateQuestionDefinition(
            {'type': 'text', 'group': 'about', 'title': 'T'},
            id: id,
            isNew: true,
            existingIds: const {},
          ),
          isNotEmpty,
          reason: id,
        );
      }
    });

    test('format returns null for answers of the wrong type', () {
      expect(q('smoking').format(5), isNull);
      expect(q('bio').format(['x']), isNull);
      expect(q('interests').format('travel'), isNull);
      expect(q('heightCm').format('tall'), isNull);
      expect(q('attractionMen').format('x'), isNull);
      expect(q('birthDate').format('yesterday'), isNull);
    });

    test('show-only-if needs values and an earlier, shown source', () {
      final source = ProfileQuestion.fromMap('pets', {
        'type': 'single',
        'group': 'about',
        'title': 'Pets?',
        'order': 10,
        'options': [
          {'value': 'yes', 'label': 'Yes'},
        ],
      })!;
      List<String> v(
        Map<String, dynamic> showIf, {
        double order = 20,
        List<ProfileQuestion>? others,
      }) => validateQuestionDefinition(
        {
          'type': 'text',
          'group': 'about',
          'title': 'T',
          'order': order,
          'showIf': showIf,
        },
        id: 'dogName',
        isNew: true,
        existingIds: const {},
        others: others ?? [source],
      );
      expect(v({'questionId': 'pets', 'values': []}), isNotEmpty);
      expect(
        v({
          'questionId': 'pets',
          'values': ['yes'],
        }),
        isEmpty,
      );
      expect(
        v({
          'questionId': 'pets',
          'values': ['yes'],
        }, order: 5),
        isNotEmpty,
      );
      expect(
        v({
          'questionId': 'gone',
          'values': ['yes'],
        }),
        isNotEmpty,
      );
      final hidden = ProfileQuestion.fromMap('pets', {
        ...source.toMap(),
        'active': false,
      })!;
      expect(
        v(
          {
            'questionId': 'pets',
            'values': ['yes'],
          },
          others: [hidden],
        ),
        isNotEmpty,
      );
    });

    test('answers count only options that still exist', () {
      expect(
        validateAnswer(q('interests'), ['travel', 'music', 'gone']),
        isNotNull,
      );
      expect(knownValues(q('interests'), ['travel', 'gone']), ['travel']);
    });
  });
}
