import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../onboarding/questions.dart';

/// Question ids shown elsewhere on the card rather than as chips.
const _notChips = {
  'name',
  'birthDate',
  'gender',
  'interestedIn',
  'bio',
  'photoUrls',
  'interests',
};

/// Answer chips for a profile, e.g. "💍 Long-term relationship".
List<String> profileChips(AppUser user) => [
  for (final q in profileQuestions)
    if (!_notChips.contains(q.id))
      if (q.format(user[q.id]) case final text?)
        q.chipIcon == null ? text : '${q.chipIcon} $text',
];

List<String> interestChips(AppUser user) {
  final q = profileQuestions.firstWhere((q) => q.id == 'interests');
  final values = List<String>.from(user['interests'] ?? const []);
  return [
    for (final o in q.options)
      if (values.contains(o.value)) o.display,
  ];
}

/// Full-bleed photo card for the swipe deck. Tap the left/right side to
/// flip photos.
class ProfileCard extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onInfo;
  const ProfileCard({super.key, required this.user, this.onInfo});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final photos = u.photoUrls;
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isNotEmpty)
            CachedNetworkImage(
              imageUrl: photos[_photo.clamp(0, photos.length - 1)],
              fit: BoxFit.cover,
            )
          else
            Container(color: theme.colorScheme.surfaceContainerHighest),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                    () => _photo = (_photo - 1).clamp(0, photos.length - 1),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                    () => _photo = (_photo + 1).clamp(0, photos.length - 1),
                  ),
                ),
              ),
            ],
          ),
          if (photos.length > 1)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  for (var i = 0; i < photos.length; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: i == _photo ? 0.95 : 0.4,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: widget.onInfo == null,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${u.name}${u.age != null ? ', ${u.age}' : ''}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final c in profileChips(u).take(4))
                                _DarkChip(c),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.onInfo != null)
                      IconButton(
                        onPressed: widget.onInfo,
                        icon: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  final String text;
  const _DarkChip(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
  );
}

/// Scrollable full profile: photos, bio, every answer.
class ProfileDetails extends StatelessWidget {
  final AppUser user;
  const ProfileDetails({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bio = user['bio'] as String?;
    final interests = interestChips(user);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ProfileCard(user: user),
        ),
        if (bio != null && bio.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'About me',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(bio, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final c in profileChips(user)) Chip(label: Text(c))],
        ),
        if (interests.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Interests',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in interests) Chip(label: Text(c))],
          ),
        ],
        for (final url in user.photoUrls.skip(1)) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          ),
        ],
      ],
    );
  }
}
