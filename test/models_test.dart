import 'package:amore/models/app_user.dart';
import 'package:amore/models/match.dart';
import 'package:amore/onboarding/questions.dart';
import 'package:amore/widgets/profile_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser.ageOn', () {
    test('counts a birthday that already happened this year', () {
      expect(AppUser.ageOn(DateTime(2000, 3, 10), DateTime(2026, 10, 21)), 26);
    });
    test('does not count a birthday later this year', () {
      expect(AppUser.ageOn(DateTime(2000, 12, 1), DateTime(2026, 10, 21)), 25);
    });
    test('turns 18 exactly on the birthday', () {
      expect(AppUser.ageOn(DateTime(2008, 10, 21), DateTime(2026, 10, 21)), 18);
      expect(AppUser.ageOn(DateTime(2008, 10, 22), DateTime(2026, 10, 21)), 17);
    });
  });

  group('Match', () {
    test('idFor is the same regardless of order', () {
      expect(Match.idFor('bob', 'alice'), 'alice_bob');
      expect(Match.idFor('alice', 'bob'), 'alice_bob');
    });
    test('otherUser returns the other participant', () {
      const m = Match(id: 'a_b', users: ['a', 'b']);
      expect(m.otherUser('a'), 'b');
      expect(m.otherUser('b'), 'a');
    });
  });

  group('ProfileQuestion.format', () {
    ProfileQuestion q(String id) =>
        defaultQuestions.firstWhere((q) => q.id == id);

    test('single choice shows the label with emoji', () {
      expect(q('lookingFor').format('long_term'), '💍 Long-term relationship');
    });
    test('multi choice joins labels and ignores unknown values', () {
      expect(q('pets').format(['dog', 'zebra', 'cat']), '🐶 Dog, 🐱 Cat');
    });
    test('blank text and empty lists count as unanswered', () {
      expect(q('city').format('   '), isNull);
      expect(q('pets').format(<String>[]), isNull);
      expect(q('city').format(null), isNull);
    });
    test('height shows cm and feet/inches', () {
      expect(q('heightCm').format(180), '180 cm (5\'11")');
    });
    test('date formats day/month/year', () {
      expect(
        q('birthDate').format(Timestamp.fromDate(DateTime(1999, 4, 7))),
        '7/4/1999',
      );
    });
  });

  test('question ids are unique', () {
    final ids = defaultQuestions.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('profile chips prefix ambiguous answers with their icon', () {
    const user = AppUser('u', {
      'drinking': 'no',
      'smoking': 'no',
      'pets': ['dog'],
      'name': 'Sara',
    });
    expect(profileChips(user, defaultQuestions), ['🍷 No', '🚬 No', '🐶 Dog']);
  });
}
