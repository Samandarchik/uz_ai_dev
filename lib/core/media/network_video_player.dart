import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Tarmoqdagi (URL) videoni AYLANA shaklida ko'rsatadigan to'liq ekran.
///
/// Video kvadrat (1:1) saqlangani uchun [ClipOval] bilan to'liq doira chiqadi —
/// Telegram video note kabi. Bosilganda play/pause, avtomatik takrorlanadi.
class CircularNetworkVideoPlayer extends StatefulWidget {
  final String url;
  const CircularNetworkVideoPlayer({super.key, required this.url});

  @override
  State<CircularNetworkVideoPlayer> createState() =>
      _CircularNetworkVideoPlayerState();
}

class _CircularNetworkVideoPlayerState
    extends State<CircularNetworkVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = c;
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _isPlaying = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (_isPlaying) {
        c.pause();
        _isPlaying = false;
      } else {
        c.play();
        _isPlaying = true;
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = MediaQuery.of(context).size.width * 0.9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _buildContent(diameter)),

          // Pauza paytida play ikonkasi.
          if (_initialized && !_isPlaying)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),

          // Yopish tugmasi.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double diameter) {
    if (_hasError) {
      return const Text(
        'Videoni yuklashda xatolik',
        style: TextStyle(color: Colors.white),
      );
    }
    if (!_initialized || _controller == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return GestureDetector(
      onTap: _togglePlayPause,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: ClipOval(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      ),
    );
  }
}
