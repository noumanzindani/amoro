import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/block_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/user_repository.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import '../profile/user_profile_screen.dart';

/// Everyone on Amore. Tap a person to see their profile and message them
/// directly — no match needed.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<AppUser>> _people = _load();
  String _query = '';

  Future<List<AppUser>> _load() => context.read<UserRepository>().community();

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _people = next);
    await next;
  }

  bool _matches(AppUser u) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final city = (u['city'] as String? ?? '').toLowerCase();
    return u.name.toLowerCase().contains(q) || city.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<SessionProvider>().uid;
    final blocks = context.watch<BlockProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or city',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: _people,
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('community load failed: ${snap.error}');
                  return _Message(
                    text: 'Couldn\'t load people.',
                    onRetry: _refresh,
                  );
                }
                if (!snap.hasData) return const Center(child: AppLoader());
                final people = snap.data!
                    .where(
                      (u) =>
                          u.uid != me && !blocks.isHidden(u.uid) && _matches(u),
                    )
                    .toList();
                return RefreshIndicator(
                  color: AppColors.rose,
                  backgroundColor: AppColors.surface,
                  onRefresh: _refresh,
                  child: people.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                _query.isEmpty
                                    ? 'No one here yet.'
                                    : 'No one matches "$_query".',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 3 / 4,
                              ),
                          itemCount: people.length,
                          itemBuilder: (context, i) =>
                              _PersonTile(user: people[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final AppUser user;
  const _PersonTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final photo = user.photoUrls.firstOrNull;
    final city = user['city'] as String?;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => UserProfileScreen(user: user)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
            else
              const ColoredBox(
                color: AppColors.surface,
                child: Icon(Icons.person, size: 48, color: AppColors.muted),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user.name}${user.age != null ? ', ${user.age}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (city != null && city.isNotEmpty)
                    Text(
                      '📍 $city',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Future<void> Function() onRetry;
  const _Message({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          child: AppButton(text: 'Retry', onPressed: onRetry),
        ),
      ],
    ),
  );
}
