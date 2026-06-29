import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// Aylana ("Telegram uslubidagi") videoni yozib bo'lgach ko'rsatiladigan
// preview ekrani. Segmentlarni ketma-ket avtoplay qiladi; "Yuborish" yoki
// "Qaytadan" tugmasi bilan natijani qaytaradi:
//   pop({'action': 'send', 'segments': [...]})  yoki  pop({'action': 'retake'})
class VideoPreviewScreen extends StatefulWidget {
  final List<String> videoSegments;
  final int taskId;

  const VideoPreviewScreen({
    super.key,
    required this.videoSegments,
    this.taskId = 0,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _controller;

  bool _isInitialized = false;
  bool _isPlaying = false;
  int _currentSegmentIndex = 0;
  bool _isLoadingNextSegment = false;

  @override
  void initState() {
    super.initState();
    _initializeCurrentSegment();
  }

  Future<void> _initializeCurrentSegment() async {
    if (_currentSegmentIndex >= widget.videoSegments.length) {
      _currentSegmentIndex = 0;
    }

    try {
      await _controller?.dispose();

      _controller = VideoPlayerController.file(
        File(widget.videoSegments[_currentSegmentIndex]),
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoadingNextSegment = false;
        });

        _controller!.play();
        setState(() {
          _isPlaying = true;
        });

        _controller!.addListener(_onVideoProgress);
      }
    } catch (e) {
      _showError("Ошибка при загрузке видео: $e");
    }
  }

  void _onVideoProgress() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.position >= _controller!.value.duration) {
      if (!_isLoadingNextSegment) {
        _playNextSegment();
      }
    }
  }

  Future<void> _playNextSegment() async {
    setState(() {
      _isLoadingNextSegment = true;
    });

    _currentSegmentIndex++;

    if (_currentSegmentIndex >= widget.videoSegments.length) {
      // Barchasi tugadi, qayta boshidan
      _currentSegmentIndex = 0;
    }

    await _initializeCurrentSegment();
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _sendVideo() {
    Navigator.of(
      context,
    ).pop({'action': 'send', 'segments': widget.videoSegments});
  }

  void _retakeVideo() {
    Navigator.of(context).pop({'action': 'retake'});
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diameter = size.width * 0.9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Blurlangan orqa fon (videoning o'zidan) ──
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
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

          // Orqa fonni yengil qoraytirish (doira ajralib tursin)
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),

          // ── Markazda aylana (aniq) video ──
          if (_isInitialized && _controller != null)
            Center(
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
            ),

          // Aylana oq border
          if (_isInitialized)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ),

          // Yuklash indikatori
          if (!_isInitialized || _isLoadingNextSegment)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),

          // Play/Pause overlay (markazda)
          if (_isInitialized && !_isLoadingNextSegment)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _isPlaying ? 0.0 : 0.8,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Segment counter va progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Segment progress dots
                      if (widget.videoSegments.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 8),
                          child: Row(
                            children: List.generate(
                              widget.videoSegments.length,
                              (index) => Container(
                                margin: const EdgeInsets.only(right: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index <= _currentSegmentIndex
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Qaytadan olish
                    _buildActionButton(
                      icon: Icons.refresh,
                      label: 'Заново',
                      onTap: _retakeVideo,
                      color: Colors.white,
                    ),

                    // Yuborish
                    _buildActionButton(
                      icon: Icons.send,
                      label: 'Отправить',
                      onTap: _sendVideo,
                      color: Colors.blue,
                      isPrimary: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: isPrimary ? 0 : 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
