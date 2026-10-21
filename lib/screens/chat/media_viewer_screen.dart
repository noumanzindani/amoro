import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/message.dart';
import '../../services/secure_screen.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

/// Full-screen photo/video. For view-once media, screenshots are blocked
/// (Android) while it's open; the caller deletes it after this route pops.
class MediaViewerScreen extends StatefulWidget {
  final File file;
  final MessageType type;
  final bool viewOnce;

  const MediaViewerScreen({
    super.key,
    required this.file,
    required this.type,
    this.viewOnce = false,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    if (widget.viewOnce) SecureScreen.enable();
    if (widget.type == MessageType.video) {
      _video = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _video!.play();
        });
      _video!.addListener(_onVideoTick);
    }
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    if (widget.viewOnce) SecureScreen.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const CircleBackButton(),
        title: widget.viewOnce
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔥 ', style: TextStyle(fontSize: 18)),
                  Text(
                    'View once',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : null,
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: widget.type == MessageType.photo
            ? InteractiveViewer(child: Image.file(widget.file))
            : (video == null || !video.value.isInitialized)
            ? const AppLoader()
            : GestureDetector(
                onTap: () =>
                    video.value.isPlaying ? video.pause() : video.play(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: video.value.aspectRatio,
                      child: VideoPlayer(video),
                    ),
                    if (!video.value.isPlaying)
                      const CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: VideoProgressIndicator(
                        video,
                        allowScrubbing: !widget.viewOnce,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.rose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
