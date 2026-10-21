import 'package:amore/onboarding/questions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProfileQuestion q(String id) =>
      profileQuestions.firstWhere((q) => q.id == id);
  Timestamp yearsAgo(int years, {int days = 0}) {
    final now = DateTime.now();
    return Timestamp.fromDate(
      DateTime(now.year - years, now.month, now.day + days),
    );
  }

  test('required questions reject empty answers', () {
    expect(validateAnswer(q('name'), null), isNotNull);
    expect(validateAnswer(q('name'), '   '), isNotNull);
    expect(validateAnswer(q('interestedIn'), <String>[]), isNotNull);
    expect(validateAnswer(q('name'), 'Sara'), isNull);
  });

  test('optional questions accept empty answers', () {
    expect(validateAnswer(q('city'), null), isNull);
    expect(validateAnswer(q('pets'), <String>[]), isNull);
  });

  test('birthday must be 18+', () {
    expect(validateAnswer(q('birthDate'), yearsAgo(18)), isNull);
    expect(validateAnswer(q('birthDate'), yearsAgo(18, days: 1)), isNotNull);
    expect(validateAnswer(q('birthDate'), yearsAgo(16)), isNotNull);
    expect(validateAnswer(q('birthDate'), yearsAgo(120)), isNotNull);
  });

  test('interests need 3 to 10', () {
    expect(validateAnswer(q('interests'), ['a', 'b']), isNotNull);
    expect(validateAnswer(q('interests'), ['a', 'b', 'c']), isNull);
    expect(
      validateAnswer(q('interests'), List.generate(11, (i) => '$i')),
      isNotNull,
    );
  });

  test('photos need at least one, at most six', () {
    expect(validateAnswer(q('photoUrls'), <String>[]), isNotNull);
    expect(validateAnswer(q('photoUrls'), ['u']), isNull);
    expect(
      validateAnswer(q('photoUrls'), List.generate(7, (i) => 'u$i')),
      isNotNull,
    );
  });

  test('normalizeAnswer trims text and empties become null', () {
    expect(normalizeAnswer('  Sara '), 'Sara');
    expect(normalizeAnswer('   '), isNull);
    expect(normalizeAnswer(<String>[]), isNull);
    expect(normalizeAnswer(['dog']), ['dog']);
    expect(normalizeAnswer(170), 170);
  });
}
