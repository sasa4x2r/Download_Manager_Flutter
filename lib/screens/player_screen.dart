import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PlayerScreen extends StatefulWidget {
  final String path;
  final String title;
  const PlayerScreen({super.key, required this.path, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final video = VideoPlayerController.file(File(widget.path));
      await video.initialize();
      final chewie = ChewieController(
        videoPlayerController: video,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
      );
      if (!mounted) {
        await video.dispose();
        return;
      }
      setState(() {
        _video = video;
        _chewie = chewie;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تشغيل الفيديو:\n$e');
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: Center(
      child: _error != null
          ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
          : _chewie == null
              ? const CircularProgressIndicator()
              : AspectRatio(
                  aspectRatio: _video!.value.aspectRatio,
                  child: Chewie(controller: _chewie!),
                ),
    ),
  );
}
