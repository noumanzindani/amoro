import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime? a, DateTime? b) =>
    a != null && b != null && _day(a) == _day(b);

/// "Today", "Yesterday", a weekday within the last week, else "12 Oct" (+ year if not this year).
String dayLabel(DateTime date, DateTime now) {
  final days = _day(now).difference(_day(date)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days > 1 && days < 7) return _weekdays[date.weekday - 1];
  final base = '${date.day} ${_months[date.month - 1]}';
  return date.year == now.year ? base : '$base ${date.year}';
}

class DateHeader extends StatelessWidget {
  final DateTime date;
  const DateHeader(this.date, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          dayLabel(date, DateTime.now()),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

enum Receipt { pending, sent, seen }

/// One message: text, photo, video, or view-once card, with time and receipt.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool mine;
  final Receipt receipt;
  final Future<File> Function(Message) loadMedia;
  final void Function(Message) onOpenMedia;

  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.receipt,
    required this.loadMedia,
    required this.onOpenMedia,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    final Widget content;
    if (m.viewOnce) {
      content = _ViewOnceCard(
        message: m,
        mine: mine,
        onTap: () => onOpenMedia(m),
      );
    } else if (m.type == MessageType.photo) {
      content = _PhotoThumb(
        message: m,
        loadMedia: loadMedia,
        onTap: () => onOpenMedia(m),
      );
    } else if (m.type == MessageType.video) {
      content = _VideoTile(onTap: () => onOpenMedia(m));
    } else {
      content = Text(
        m.text,
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
      );
    }
    final padded = m.isMedia && !m.viewOnce;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: padded
            ? const EdgeInsets.all(4)
            : const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.rose : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            Padding(
              padding: padded
                  ? const EdgeInsets.fromLTRB(0, 4, 6, 2)
                  : const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.createdAt == null
                        ? ''
                        : MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay.fromDateTime(m.createdAt!),
                          ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    _ReceiptIcon(receipt),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptIcon extends StatelessWidget {
  final Receipt receipt;
  const _ReceiptIcon(this.receipt);

  @override
  Widget build(BuildContext context) {
    switch (receipt) {
      case Receipt.pending:
        return Icon(
          Icons.schedule,
          size: 13,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case Receipt.sent:
        return Icon(
          Icons.done,
          size: 15,
          color: Colors.white.withValues(alpha: 0.7),
        );
      case Receipt.seen:
        return const Icon(Icons.done_all, size: 15, color: Colors.white);
    }
  }
}

class _PhotoThumb extends StatefulWidget {
  final Message message;
  final Future<File> Function(Message) loadMedia;
  final VoidCallback onTap;
  const _PhotoThumb({
    required this.message,
    required this.loadMedia,
    required this.onTap,
  });

  @override
  State<_PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<_PhotoThumb> {
  late final Future<File> _file = widget.loadMedia(widget.message);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 220,
        height: 260,
        child: FutureBuilder<File>(
          future: _file,
          builder: (context, snap) {
            if (snap.hasError) {
              return const ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
                ),
              );
            }
            if (!snap.hasData) {
              return const ColoredBox(
                color: Colors.black26,
                child: Center(child: AppLoader(size: 22)),
              );
            }
            return Image.file(snap.data!, fit: BoxFit.cover);
          },
        ),
      ),
    ),
  );
}

class _VideoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _VideoTile({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        height: 140,
        color: Colors.black38,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
            SizedBox(height: 6),
            Text(
              'Video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A view-once item never shows a preview. The receiver can open it once;
/// afterwards (and always for the sender) it only shows its status.
class _ViewOnceCard extends StatelessWidget {
  final Message message;
  final bool mine;
  final VoidCallback onTap;
  const _ViewOnceCard({
    required this.message,
    required this.mine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = message.type == MessageType.video;
    final kind = isVideo ? 'Video' : 'Photo';
    final canOpen = !mine && !message.opened;
    final status = message.opened
        ? 'Opened'
        : (mine ? 'View once' : 'Tap to view');
    return GestureDetector(
      onTap: canOpen ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: canOpen ? 1 : 0.4),
                width: 2,
              ),
            ),
            child: Icon(
              message.opened
                  ? Icons.check
                  : (isVideo ? Icons.play_arrow : Icons.local_fire_department),
              color: Colors.white.withValues(alpha: canOpen ? 1 : 0.6),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kind,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
