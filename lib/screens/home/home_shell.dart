import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/match.dart';
import '../../providers/block_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/swipe_repository.dart';
import '../../widgets/ui.dart';

class HomeShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  const HomeShell({super.key, required this.shell});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final String _me = context.read<SessionProvider>().uid!;
  late final Stream<List<Match>> _matches = context
      .read<SwipeRepository>()
      .watchMatches(_me);

  @override
  Widget build(BuildContext context) => Scaffold(
    // Content scrolls under the floating pill, like IMIC.
    extendBody: true,
    body: widget.shell,
    bottomNavigationBar: StreamBuilder<List<Match>>(
      stream: _matches,
      builder: (context, snap) {
        final blocks = context.watch<BlockProvider>();
        final unread = (snap.data ?? const <Match>[])
            .where((m) => !blocks.isHidden(m.otherUser(_me)))
            .fold<int>(0, (sum, m) => sum + m.unreadFor(_me));
        return FloatingNavBar(
          items: [
            const NavItem(Icons.style_outlined, Icons.style, 'Discover'),
            const NavItem(Icons.people_outline, Icons.people, 'Community'),
            NavItem(
              Icons.chat_bubble_outline,
              Icons.chat_bubble,
              'Chats',
              badge: unread,
            ),
            const NavItem(Icons.person_outline, Icons.person, 'Profile'),
          ],
          selectedIndex: widget.shell.currentIndex,
          onTap: (i) => widget.shell.goBranch(
            i,
            initialLocation: i == widget.shell.currentIndex,
          ),
        );
      },
    ),
  );
}
