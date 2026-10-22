import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../onboarding/questions.dart';
import '../theme.dart';

/// Roughly how the question looks on a phone during sign-up. Static: the
/// real inputs need the app's services, which the admin panel doesn't load.
class QuestionPreview extends StatelessWidget {
  final ProfileQuestion? question;
  const QuestionPreview({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;
    return Container(
      width: 320,
      height: 600,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: q == null
          ? const Center(
              child: Text(
                'Fill in the form to see a preview',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.group.label,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    q.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (q.subtitle case final s? when s.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(s, style: const TextStyle(color: AppColors.muted)),
                  ],
                  const SizedBox(height: 20),
                  _answer(q),
                  const SizedBox(height: 20),
                  Text(
                    [
                      q.required ? 'Required' : 'Optional (Skip shown)',
                      q.private ? 'Private' : 'Public on profile',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _box(IconData icon, String text) => Container(
    height: 120,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.outline, width: 2),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.rose, size: 32),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    ),
  );

  Widget _answer(ProfileQuestion q) {
    switch (q.type) {
      case QuestionType.single:
      case QuestionType.multi:
        if (q.hasImageOptions) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
            children: [
              for (final o in q.options)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: o.imageUrl == null
                            ? Center(
                                child: Text(
                                  o.emoji ?? '',
                                  style: const TextStyle(fontSize: 32),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: o.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          o.display,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final o in q.options) Chip(label: Text(o.display))],
        );
      case QuestionType.text:
      case QuestionType.longText:
        return TextField(
          enabled: false,
          maxLines: q.type == QuestionType.longText ? 4 : 1,
          decoration: const InputDecoration(hintText: 'Type your answer'),
        );
      case QuestionType.date:
        return _box(Icons.calendar_month_outlined, 'Choose date');
      case QuestionType.height:
        return _box(Icons.height, 'Height slider');
      case QuestionType.scale:
        final mid = ((q.scaleMin + q.scaleMax) / 2).round();
        return Column(
          children: [
            Text(q.format(mid) ?? '$mid'),
            Slider(
              value: mid.toDouble(),
              min: q.scaleMin.toDouble(),
              max: q.scaleMax.toDouble(),
              onChanged: null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(q.lowLabel ?? '${q.scaleMin}'),
                Text(q.highLabel ?? '${q.scaleMax}'),
              ],
            ),
          ],
        );
      case QuestionType.photos:
        final n = q.maxSelect ?? 1;
        return _box(
          Icons.add_a_photo_outlined,
          'Upload ${q.minSelect ?? 1}–$n photo${n == 1 ? '' : 's'}',
        );
      case QuestionType.video:
        return _box(
          Icons.videocam_outlined,
          'Record ${formatVideoLength(q.videoLength ?? Duration.zero)}',
        );
    }
  }
}
