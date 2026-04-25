import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';

class MediaViewer extends StatefulWidget {
  final MediaItem item;

  const MediaViewer({super.key, required this.item});

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  static const _pink = Color(0xFFFFB3D9);

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _showPlayOverlay = false;

  @override
  void initState() {
    super.initState();
    _initializeForItem();
  }

  @override
  void didUpdateWidget(covariant MediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _disposeVideo();
      _initializeForItem();
    }
  }

  void _initializeForItem() {
    if (widget.item.isVideo) {
      _initializeVideo(path: widget.item.path, loop: true, autoPlay: true);
      return;
    }
    if (widget.item.isLivePhoto && widget.item.liveVideoPath != null) {
      _initializeVideo(
        path: widget.item.liveVideoPath!,
        loop: false,
        autoPlay: true,
      );
    }
  }

  Future<void> _initializeVideo({
    required String path,
    required bool loop,
    required bool autoPlay,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return;
    }

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    await controller.setLooping(loop);
    if (autoPlay) {
      await controller.play();
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _videoController = controller;
      _videoInitialized = true;
    });
  }

  Future<void> _disposeVideo() async {
    final controller = _videoController;
    _videoController = null;
    _videoInitialized = false;
    _showPlayOverlay = false;
    if (controller != null) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.isVideo) {
      return _buildVideoView();
    }
    if (widget.item.isLivePhoto &&
        _videoInitialized &&
        _videoController != null) {
      return _buildLivePhotoView();
    }
    return _buildImageView();
  }

  Widget _buildImageView() {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          File(widget.item.path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text('Failed to load image');
          },
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    final controller = _videoController;
    if (!_videoInitialized || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 52),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                  if (!mounted) return;
                  setState(() => _showPlayOverlay = true);
                } else {
                  await controller.play();
                  if (!mounted) return;
                  setState(() => _showPlayOverlay = false);
                }
              },
              child: Center(
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 44,
          left: 12,
          right: 12,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 6),
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              colors: const VideoProgressColors(
                playedColor: _pink,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.black,
              ),
            ),
          ),
        ),
        if (_showPlayOverlay)
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.play_arrow, size: 42, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLivePhotoView() {
    final controller = _videoController;
    if (!_videoInitialized || controller == null) {
      return _buildImageView();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 52,
          right: 16,
          child: Row(
            children: [
              FloatingActionButton.small(
                heroTag: 'live-replay-${widget.item.id}',
                onPressed: () async {
                  await controller.seekTo(Duration.zero);
                  await controller.play();
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                highlightElevation: 0,
                foregroundColor: _pink,
                shape: const CircleBorder(),
                child: const Icon(Icons.replay),
              ),
              const SizedBox(width: 8),
              const Text(
                '实况',
                style: TextStyle(
                  color: _pink,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
