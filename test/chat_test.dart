import 'package:amore/models/match.dart';
import 'package:amore/models/message.dart';
import 'package:amore/screens/chat/chat_bubbles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayLabel', () {
    final now = DateTime(2026, 10, 21, 9);
    test('today and yesterday', () {
      expect(dayLabel(DateTime(2026, 10, 21, 0, 5), now), 'Today');
      expect(dayLabel(DateTime(2026, 10, 20, 23, 59), now), 'Yesterday');
    });
    test('weekday within the last week', () {
      expect(dayLabel(DateTime(2026, 10, 17), now), 'Saturday');
    });
    test('day and month this year, with year otherwise', () {
      expect(dayLabel(DateTime(2026, 10, 1), now), '1 Oct');
      expect(dayLabel(DateTime(2025, 12, 31), now), '31 Dec 2025');
    });
    test('sameDay ignores time', () {
      expect(
        sameDay(DateTime(2026, 1, 1, 1), DateTime(2026, 1, 1, 23)),
        isTrue,
      );
      expect(sameDay(DateTime(2026, 1, 1), DateTime(2026, 1, 2)), isFalse);
      expect(sameDay(null, DateTime(2026)), isFalse);
    });
  });

  group('Match chat state', () {
    final now = DateTime(2026, 10, 21, 12);
    final m = Match(
      id: 'a_b',
      users: const ['a', 'b'],
      unreadCount: const {'a': 3},
      typing: {
        'b': now.subtract(const Duration(seconds: 2)),
        'a': now.subtract(const Duration(seconds: 30)),
      },
    );
    test('unread defaults to 0', () {
      expect(m.unreadFor('a'), 3);
      expect(m.unreadFor('b'), 0);
    });
    test('typing expires after a few seconds', () {
      expect(m.isTyping('b', now), isTrue);
      expect(m.isTyping('a', now), isFalse);
    });
    test('activityAt prefers last message time', () {
      final older = Match(
        id: 'x',
        users: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      final newer = Match(
        id: 'y',
        users: const [],
        createdAt: DateTime(2025, 1, 1),
        lastMessageAt: DateTime(2026, 6, 1),
      );
      final list = [older, newer]
        ..sort((a, b) => b.activityAt.compareTo(a.activityAt));
      expect(list.first.id, 'y');
    });
  });

  test('previews describe media without revealing it', () {
    expect(
      Message.previewFor(MessageType.photo, viewOnce: true),
      '🔥 View-once photo',
    );
    expect(Message.previewFor(MessageType.video, viewOnce: false), '🎥 Video');
    expect(
      Message.previewFor(MessageType.text, viewOnce: false, text: 'hey'),
      'hey',
    );
  });
}
