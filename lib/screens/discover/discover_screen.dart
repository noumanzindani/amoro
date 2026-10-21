import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/block_provider.dart';
import '../../providers/deck_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/profile_card.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/ui.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _swiper = CardSwiperController();
  bool _deckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _swiper.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final me = context.read<SessionProvider>().profile;
    if (me == null) return;
    setState(() => _deckDone = false);
    final hidden = context.read<BlockProvider>();
    await context.read<DeckProvider>().load(me, hidden: hidden.hiddenIds);
  }

  Future<bool> _onSwipe(
    List<AppUser> cards,
    int index,
    CardSwiperDirection dir,
  ) async {
    final deck = context.read<DeckProvider>();
    final me = context.read<SessionProvider>().uid!;
    final other = cards[index];
    try {
      if (dir == CardSwiperDirection.right) {
        final matched = await deck.like(me, other);
        if (matched && mounted) _showMatch(other);
      } else {
        await deck.pass(me, other);
      }
      return true;
    } catch (e) {
      debugPrint('swipe failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t save that swipe.')),
        );
      }
      return false;
    }
  }

  void _showMatch(AppUser other) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.favorite, size: 48),
        title: const Text("It's a match!"),
        content: Text(
          'You and ${other.name} liked each other. Say hi from the Matches tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep swiping'),
          ),
        ],
      ),
    );
  }

  void _showDetails(AppUser user) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => UserProfileScreen(user: user)),
  );

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();
    final cards = deck.cards;
    Widget body;
    if (deck.loading) {
      body = const Center(child: AppLoader());
    } else if (deck.error != null || cards.isEmpty || _deckDone) {
      body = _Empty(
        message: deck.error ?? "You've seen everyone for now. Check back soon!",
        onRetry: _reload,
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: CardSwiper(
              controller: _swiper,
              cardsCount: cards.length,
              numberOfCardsDisplayed: cards.length < 3 ? cards.length : 3,
              isLoop: false,
              allowedSwipeDirection: const AllowedSwipeDirection.only(
                left: true,
                right: true,
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              onSwipe: (prev, _, dir) => _onSwipe(cards, prev, dir),
              onEnd: () => setState(() => _deckDone = true),
              cardBuilder: (context, i, _, _) => ProfileCard(
                user: cards[i],
                onInfo: () => _showDetails(cards[i]),
              ),
            ),
          ),
          Padding(
            // Leaves room for the floating nav bar.
            padding: const EdgeInsets.only(bottom: 96),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundAction(
                  icon: Icons.close,
                  color: const Color(0xFF191919),
                  tooltip: 'Pass',
                  onTap: () => _swiper.swipe(CardSwiperDirection.left),
                ),
                const SizedBox(width: 32),
                _RoundAction(
                  icon: Icons.favorite,
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: 'Like',
                  size: 72,
                  onTap: () => _swiper.swipe(CardSwiperDirection.right),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: body,
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Empty({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.travel_explore,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: AppButton(text: 'Refresh', onPressed: onRetry),
          ),
        ],
      ),
    ),
  );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final double size;
  final VoidCallback onTap;
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
      ),
    ),
  );
}
