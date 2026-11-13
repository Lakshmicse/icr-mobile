import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

/// Plays a discussion's video (owner, 11 Nov 2026: "playing functionalities"): a black page with the video, a
/// play/pause button over it, a seek bar with the time, opened over whatever showed the tile. Built on
/// `video_player` alone (the ready-made control packages lag the Flutter the app is on). A video that will not play
/// says so.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _video;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final video = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _video = video;
      await video.initialize();
      if (!mounted) return;
      video.addListener(_tick);
      setState(() => _ready = true);
      await video.play();
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't play this video. Check your connection and try again.");
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.removeListener(_tick);
    _video?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final v = _video;
    if (v == null || !_ready) return;
    if (v.value.isPlaying) {
      await v.pause();
    } else {
      // At the end, a tap starts it over.
      if (v.value.position >= v.value.duration) await v.seekTo(Duration.zero);
      await v.play();
    }
  }

  static String _clock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final playing = v?.value.isPlaying ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('video-close'),
          tooltip: 'Close',
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: widget.title == null ? null : Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  key: const ValueKey('video-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            )
          : !_ready || v == null
          ? const Center(
              child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white70)),
            )
          : Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('video-surface'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayer(v),
                            if (!playing)
                              Center(
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(color: Color(0xE6FFFFFF), shape: BoxShape.circle),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      v.value.position >= v.value.duration && v.value.duration > Duration.zero
                                          ? LucideIcons.rotateCcw
                                          : LucideIcons.play,
                                      size: 32,
                                      color: const Color(0xFF1F1F1F),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('video-toggle'),
                          tooltip: playing ? 'Pause' : 'Play',
                          color: Colors.white,
                          icon: Icon(playing ? LucideIcons.pause : LucideIcons.play),
                          onPressed: _toggle,
                        ),
                        Text(_clock(v.value.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: VideoProgressIndicator(
                            v,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_clock(v.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Opens [url] in the player, over the current page.
Future<void> openVideo(BuildContext context, String url, {String? title}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => VideoPlayerScreen(url: url, title: title),
  ),
);
