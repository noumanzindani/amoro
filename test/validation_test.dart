import 'package:amore/onboarding/questions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProfileQuestion q(String id) =>
      defaultQuestions.firstWhere((q) => q.id == id);
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
    final values = q('interests').options.map((o) => o.value).toList();
    expect(validateAnswer(q('interests'), values.take(2).toList()), isNotNull);
    expect(validateAnswer(q('interests'), values.take(3).toList()), isNull);
    expect(validateAnswer(q('interests'), values.take(11).toList()), isNotNull);
  });

  test('exactly one public profile photo', () {
    expect(validateAnswer(q('photoUrls'), <String>[]), isNotNull);
    expect(validateAnswer(q('photoUrls'), ['u']), isNull);
    expect(
      validateAnswer(q('photoUrls'), ['a', 'b']),
      'You can choose up to 1 photo.',
    );
  });

  test('private photos and video are asked of women only', () {
    for (final id in ['privatePhotos', 'privateVideo']) {
      expect(q(id).appliesTo({'gender': 'woman'}), isTrue);
      expect(q(id).appliesTo({'gender': 'man'}), isFalse);
      expect(q(id).appliesTo({'gender': 'nonbinary'}), isFalse);
      expect(q(id).appliesTo({}), isFalse);
    }
    expect(q('photoUrls').appliesTo({'gender': 'man'}), isTrue);
  });

  test('attraction and first-discovery questions are private sliders', () {
    for (final id in [
      'attractionWomen',
      'attractionMen',
      'firstSexualAwarenessAge',
    ]) {
      expect(q(id).private, isTrue, reason: id);
      expect(q(id).required, isFalse, reason: id);
      expect(q(id).type, QuestionType.scale, reason: id);
      for (final g in ['woman', 'man', 'nonbinary']) {
        expect(q(id).appliesTo({'gender': g}), isTrue);
      }
    }
    expect(q('attractionMen').format(7), '7 / 10');
    expect(q('attractionWomen').scaleMax, 10);
    expect(q('firstSexualAwarenessAge').format(12), 'Age 12');
    expect(q('firstSexualAwarenessAge').scaleMin, 5);
    expect(validateAnswer(q('attractionMen'), null), isNull); // skippable
  });

  test('everyone records the private 2-minute video', () {
    final long = q('privateVideoLong');
    expect(long.private, isTrue);
    expect(long.required, isTrue);
    expect(long.videoLength, const Duration(seconds: 120));
    for (final g in ['woman', 'man', 'nonbinary']) {
      expect(long.appliesTo({'gender': g}), isTrue);
    }
    expect(q('privateVideo').videoLength, const Duration(seconds: 30));
  });

  test('video lengths read naturally', () {
    expect(formatVideoLength(const Duration(seconds: 30)), '30 seconds');
    expect(formatVideoLength(const Duration(seconds: 120)), '2 minutes');
    expect(formatVideoLength(const Duration(seconds: 60)), '1 minute');
    expect(formatVideoLength(const Duration(seconds: 90)), '1 min 30 s');
  });

  test('the 30-second video is required and private', () {
    expect(q('privateVideo').private, isTrue);
    expect(validateAnswer(q('privateVideo'), null), isNotNull);
    expect(validateAnswer(q('privateVideo'), 'users/u/private/1.mp4'), isNull);
    expect(q('privateVideo').format('users/u/private/1.mp4'), 'Video recorded');
  });

  test('exactly three private photos', () {
    expect(q('privatePhotos').private, isTrue);
    expect(q('photoUrls').private, isFalse);
    expect(validateAnswer(q('privatePhotos'), <String>[]), isNotNull);
    expect(validateAnswer(q('privatePhotos'), ['a']), 'Add 2 more photos.');
    expect(validateAnswer(q('privatePhotos'), ['a', 'b']), 'Add 1 more photo.');
    expect(validateAnswer(q('privatePhotos'), ['a', 'b', 'c']), isNull);
    expect(validateAnswer(q('privatePhotos'), ['a', 'b', 'c', 'd']), isNotNull);
  });

  test('normalizeAnswer trims text and empties become null', () {
    expect(normalizeAnswer('  Sara '), 'Sara');
    expect(normalizeAnswer('   '), isNull);
    expect(normalizeAnswer(<String>[]), isNull);
    expect(normalizeAnswer(['dog']), ['dog']);
    expect(normalizeAnswer(170), 170);
  });
}
