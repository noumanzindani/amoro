import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/match.dart';
import '../../models/message.dart';
import '../../providers/block_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/chat_repository.dart';
import '../../services/user_repository.dart';
import '../../theme.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/ui.dart';
import 'chat_bubbles.dart';
import 'media_viewer_screen.dart';

const _maxVideoBytes = 50 * 1024 * 1024;

class ChatScreen extends StatefulWidget {
  final String matchId;
  final AppUser? other;
  const ChatScreen({super.key, required this.matchId, this.other});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  late final ChatRepository _chat = context.read<ChatRepository>();
  late final String _me = context.read<SessionProvider>().uid!;
  late final Stream<List<Message>> _messages = _chat.watchMessages(
    widget.matchId,
  );
  late final String _otherId = Match(
    id: widget.matchId,
    users: widget.matchId.split('_'),
  ).otherUser(_me);
  late final Future<AppUser?> _other = widget.other != null
      ? Future.value(widget.other)
      : context.read<UserRepository>().get(_otherId);

  StreamSubscription<Match>? _matchSub;
  Match? _match;
  Timer? _typingTicker;
  DateTime? _typingSentAt;
  bool _marking = false;
  bool _sendingMedia = false;

  @override
  void initState() {
    super.initState();
    _matchSub = _chat.watchMatch(widget.matchId).listen(_onMatch);
    _markRead();
    // Re-evaluates "typing…" so it disappears once the other person stops.
    _typingTicker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _match?.typing[_otherId] != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _typingTicker?.cancel();
    if (_typingSentAt != null) {
      _chat.setTyping(widget.matchId, _me, false).ignore();
    }
    _text.dispose();
    super.dispose();
  }

  void _onMatch(Match m) {
    setState(() => _match = m);
    if (m.unreadFor(_me) > 0) _markRead();
  }

  Future<void> _markRead() async {
    if (_marking) return;
    _marking = true;
    try {
      await _chat.markRead(widget.matchId, _me);
    } catch (e) {
      debugPrint('markRead failed: $e');
    } finally {
      _marking = false;
    }
  }

  void _onTextChanged(String value) {
    final now = DateTime.now();
    if (value.trim().isEmpty) return;
    // Throttled: one write every 3s while typing.
    if (_typingSentAt == null ||
        now.difference(_typingSentAt!).inSeconds >= 3) {
      _typingSentAt = now;
      _chat.setTyping(widget.matchId, _me, true).ignore();
    }
  }

  Future<void> _sendText() async {
    final match = _match;
    final text = _text.text;
    if (match == null || text.trim().isEmpty) return;
    _text.clear();
    _typingSentAt = null;
    try {
      await _chat.sendText(match, _me, text);
    } catch (e) {
      _text.text = text;
      _snack('Message not sent.');
    }
  }

  Future<void> _pickMedia() async {
    final choice = await showModalBottomSheet<_MediaChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _AttachSheet(),
    );
    if (choice == null || !mounted || _match == null) return;

    final picker = ImagePicker();
    final XFile? picked = choice.type == MessageType.photo
        ? await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            imageQuality: 85,
          )
        : await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 60),
          );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    if (choice.type == MessageType.video &&
        await file.length() > _maxVideoBytes) {
      _snack('That video is too large (max 50 MB).');
      return;
    }
    setState(() => _sendingMedia = true);
    try {
      await _chat.sendMedia(
        _match!,
        _me,
        file,
        type: choice.type,
        viewOnce: choice.viewOnce,
      );
    } catch (e) {
      debugPrint('sendMedia failed: $e');
      _snack('Couldn\'t send. Try again.');
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  Future<void> _openMedia(Message m) async {
    File? file;
    try {
      file = await _chat.downloadMedia(m);
    } catch (e) {
      debugPrint('downloadMedia failed: $e');
      _snack(
        m.viewOnce ? 'This is no longer available.' : 'Couldn\'t load media.',
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            MediaViewerScreen(file: file!, type: m.type, viewOnce: m.viewOnce),
      ),
    );
    if (m.viewOnce) {
      try {
        await _chat.consumeViewOnce(widget.matchId, m, file);
      } catch (e) {
        debugPrint('consumeViewOnce failed: $e');
      }
    }
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Receipt _receiptFor(Message m) {
    if (m.createdAt == null) return Receipt.pending;
    final seenUntil = _match?.lastRead[_otherId];
    return (seenUntil != null && !m.createdAt!.isAfter(seenUntil))
        ? Receipt.seen
        : Receipt.sent;
  }

  @override
  Widget build(BuildContext context) {
    final typing = _match?.isTyping(_otherId, DateTime.now()) ?? false;
    final blocked = context.watch<BlockProvider>().isHidden(_otherId);
    return FutureBuilder<AppUser?>(
      future: _other,
      builder: (context, otherSnap) {
        final other = otherSnap.data;
        final photo = other?.photoUrls.firstOrNull;
        return Scaffold(
          appBar: AppBar(
            leading: const CircleBackButton(),
            titleSpacing: 0,
            title: InkWell(
              onTap: other == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => UserProfileScreen(
                          user: other,
                          showMessage: false,
                          matchId: widget.matchId,
                        ),
                      ),
                    ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surface,
                    backgroundImage: photo == null ? null : NetworkImage(photo),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other?.name ?? 'Chat',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: typing
                            ? const Text(
                                'typing…',
                                key: ValueKey('t'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.rose,
                                ),
                              )
                            : const SizedBox(key: ValueKey('n'), height: 0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: _messages,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(
                        child: Text('Couldn\'t load messages.'),
                      );
                    }
                    if (!snap.hasData) return const Center(child: AppLoader());
                    final msgs = snap.data!;
                    if (msgs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'You matched with ${other?.name ?? 'them'}.\nSay hi! 👋',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        final older = i + 1 < msgs.length ? msgs[i + 1] : null;
                        final when = m.createdAt ?? DateTime.now();
                        final showHeader =
                            older == null ||
                            !sameDay(when, older.createdAt ?? DateTime.now());
                        return Column(
                          children: [
                            if (showHeader) DateHeader(when),
                            MessageBubble(
                              message: m,
                              mine: m.senderId == _me,
                              receipt: _receiptFor(m),
                              loadMedia: _chat.downloadMedia,
                              onOpenMedia: _openMedia,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (_sendingMedia)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppLoader(size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Sending…',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              if (blocked)
                const _BlockedBar()
              else
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Send photo or video',
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          onPressed: _sendingMedia || _match == null
                              ? null
                              : _pickMedia,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            buildCounter:
                                (
                                  _, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Message…',
                            ),
                            onChanged: _onTextChanged,
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          tooltip: 'Send',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.rose,
                            fixedSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _match == null ? null : _sendText,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaChoice {
  final MessageType type;
  final bool viewOnce;
  const _MediaChoice(this.type, this.viewOnce);
}

class _AttachSheet extends StatefulWidget {
  const _AttachSheet();

  @override
  State<_AttachSheet> createState() => _AttachSheetState();
}

class _AttachSheetState extends State<_AttachSheet> {
  bool _viewOnce = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: _viewOnce,
            onChanged: (v) => setState(() => _viewOnce = v),
            activeThumbColor: AppColors.rose,
            secondary: const Text('🔥', style: TextStyle(fontSize: 24)),
            title: const Text(
              'View once',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'They can open it one time, then it\'s deleted.',
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            text: 'Photo',
            icon: const Icon(Icons.photo_outlined, color: Colors.white),
            onPressed: () => Navigator.pop(
              context,
              _MediaChoice(MessageType.photo, _viewOnce),
            ),
          ),
          const SizedBox(height: 10),
          AppButton.light(
            text: 'Video',
            icon: const Icon(Icons.videocam_outlined, color: Colors.black),
            onPressed: () => Navigator.pop(
              context,
              _MediaChoice(MessageType.video, _viewOnce),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BlockedBar extends StatelessWidget {
  const _BlockedBar();

  @override
  Widget build(BuildContext context) => const SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'You can\'t message this person.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted),
      ),
    ),
  );
}
