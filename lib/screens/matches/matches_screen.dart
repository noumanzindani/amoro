import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/match.dart';
import '../../providers/block_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/swipe_repository.dart';
import '../../services/user_repository.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.read<SessionProvider>().uid!;
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<List<Match>>(
        stream: context.read<SwipeRepository>().watchMatches(me),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Couldn\'t load matches.'));
          }
          if (!snap.hasData) return const Center(child: AppLoader());
          final blocks = context.watch<BlockProvider>();
          final matches = snap.data!
              .where((m) => !blocks.isHidden(m.otherUser(me)))
              .toList();
          if (matches.isEmpty) {
            return const Center(
              child: Text(
                'No chats yet. Match on Discover or say hi to someone in Community.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 88),
            itemBuilder: (context, i) => _MatchTile(
              key: ValueKey(matches[i].id),
              match: matches[i],
              me: me,
            ),
          );
        },
      ),
    );
  }
}

class _MatchTile extends StatefulWidget {
  final Match match;
  final String me;
  const _MatchTile({super.key, required this.match, required this.me});

  @override
  State<_MatchTile> createState() => _MatchTileState();
}

class _MatchTileState extends State<_MatchTile> {
  // Fetched once per tile, not on every stream update.
  late final Future<AppUser?> _other = context.read<UserRepository>().get(
    widget.match.otherUser(widget.me),
  );

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final unread = match.unreadFor(widget.me);
    final typing = match.isTyping(match.otherUser(widget.me), DateTime.now());
    final fromMe = match.lastSenderId == widget.me;
    final preview = match.lastMessage == null
        ? 'New match. Say hi! 👋'
        : '${fromMe ? 'You: ' : ''}${match.lastMessage}';
    return FutureBuilder<AppUser?>(
      future: _other,
      builder: (context, snap) {
        final other = snap.data;
        final photo = other?.photoUrls.firstOrNull;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surface,
            backgroundImage: photo == null
                ? null
                : CachedNetworkImageProvider(photo),
            child: photo == null ? const Icon(Icons.person) : null,
          ),
          title: Text(
            other?.name ?? '…',
            style: TextStyle(
              fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          subtitle: Text(
            typing ? 'typing…' : preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: typing
                  ? AppColors.rose
                  : (unread > 0 ? AppColors.white : AppColors.muted),
              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: unread > 0 ? UnreadBadge(unread) : null,
          onTap: () => context.push('/chat/${match.id}', extra: other),
        );
      },
    );
  }
}
