import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/block_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/block_repository.dart';
import '../../services/chat_repository.dart';
import '../../theme.dart';
import '../../widgets/profile_card.dart';
import '../../widgets/ui.dart';

/// Someone else's profile, with Message, Report and Block.
class UserProfileScreen extends StatefulWidget {
  final AppUser user;

  /// False when opened from inside the chat with this person.
  final bool showMessage;
  final String? matchId;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.showMessage = true,
    this.matchId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _opening = false;

  Future<void> _message() async {
    setState(() => _opening = true);
    try {
      final me = context.read<SessionProvider>().uid!;
      final id = await context.read<ChatRepository>().openDirect(
        me,
        widget.user.uid,
      );
      if (mounted) context.push('/chat/$id', extra: widget.user);
    } catch (e) {
      debugPrint('openDirect failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t start the chat.')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _block() async {
    final name = widget.user.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block $name?'),
        content: const Text(
          'You won\'t see each other anywhere in Amore, and neither of you can send messages. '
          'They won\'t be told.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<BlockProvider>().block(widget.user.uid);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name is blocked.')));
    // Leave every screen that shows this person.
    Navigator.of(context).popUntil((r) => r.isFirst);
    context.go('/community');
  }

  Future<void> _report() async {
    final result = await showModalBottomSheet<_ReportResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReportSheet(name: widget.user.name),
    );
    if (result == null || !mounted) return;
    try {
      await context.read<BlockRepository>().report(
        me: context.read<SessionProvider>().uid!,
        other: widget.user.uid,
        reason: result.reason,
        details: result.details,
        matchId: widget.matchId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks. We\'ve received your report.')),
      );
      if (result.alsoBlock) {
        await context.read<BlockProvider>().block(widget.user.uid);
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
        context.go('/community');
      }
    } catch (e) {
      debugPrint('report failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t send the report.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = context.watch<BlockProvider>();
    final iBlocked = blocks.iBlocked(widget.user.uid);
    return Scaffold(
      appBar: AppBar(
        leading: const CircleBackButton(),
        title: Text(widget.user.name),
        actions: [
          PopupMenuButton<String>(
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'report') _report();
              if (v == 'block') _block();
              if (v == 'unblock') blocks.unblock(widget.user.uid);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(
                value: iBlocked ? 'unblock' : 'block',
                child: Text(
                  iBlocked ? 'Unblock' : 'Block',
                  style: const TextStyle(color: Color(0xFFFF5A5A)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ProfileDetails(user: widget.user),
      bottomNavigationBar:
          widget.showMessage && !blocks.isHidden(widget.user.uid)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: AppButton(
                  text: 'Message ${widget.user.name}',
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  loading: _opening,
                  onPressed: _message,
                ),
              ),
            )
          : null,
    );
  }
}

class _ReportResult {
  final String reason;
  final String? details;
  final bool alsoBlock;
  const _ReportResult(this.reason, this.details, this.alsoBlock);
}

class _ReportSheet extends StatefulWidget {
  final String name;
  const _ReportSheet({required this.name});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = [
    ('harassment', 'Harassment or bullying'),
    ('inappropriate', 'Inappropriate photos or messages'),
    ('spam', 'Spam or scam'),
    ('fake', 'Fake profile'),
    ('underage', 'May be under 18'),
    ('other', 'Something else'),
  ];
  String? _reason;
  bool _alsoBlock = true;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Report ${widget.name}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'They won\'t know you reported them.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final (value, label) in _reasons)
                  RadioListTile<String>(
                    value: value,
                    title: Text(label),
                    activeColor: AppColors.rose,
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          TextField(
            controller: _details,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Anything else we should know? (optional)',
            ),
          ),
          SwitchListTile(
            value: _alsoBlock,
            onChanged: (v) => setState(() => _alsoBlock = v),
            activeThumbColor: AppColors.rose,
            contentPadding: EdgeInsets.zero,
            title: Text('Also block ${widget.name}'),
          ),
          const SizedBox(height: 8),
          AppButton(
            text: 'Send report',
            onPressed: _reason == null
                ? null
                : () => Navigator.pop(
                    context,
                    _ReportResult(_reason!, _details.text, _alsoBlock),
                  ),
          ),
        ],
      ),
    ),
  );
}
