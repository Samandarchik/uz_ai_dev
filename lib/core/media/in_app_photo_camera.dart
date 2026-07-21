// core/media/in_app_photo_camera.dart — ilova ICHIDA rasm olish ekrani
// (InAppPhotoCamera): tashqi kamera ilovasini ochmaydi (xotira kam telefonlarda
// holat yo'qolmasin); Navigator.push<XFile> orqali olingan rasmni qaytaradi.
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

// Ilova ICHIDA rasm olish ekrani (tashqi kamera ilovasi OCHILMAYDI).
//
// Sabab: image_picker `ImageSource.camera` Android'da tizimning tashqi
// kamera ilovasini ochadi — shu payt xotirasi kam telefonlarda OS bizning
// ilovani orqa fonda o'ldirib yuboradi; kameradan qaytganda ilova qaytadan
// ishga tushadi va foydalanuvchi kiritgan qiymatlar (masalan omborchining
// "Kelgan soni" maydonlari) yo'qoladi. Bu ekran video yozgich
// (TelegramStyleVideoRecorder) kabi `camera` paketi bilan ilova ichida
// ishlaydi — ilova orqa fonga tushmaydi, holat yo'qolmaydi.
//
// Foydalanish: `Navigator.push<XFile>` — olingan rasm XFile bo'lib
// qaytadi, bekor qilinsa null.
class InAppPhotoCamera extends StatefulWidget {
  const InAppPhotoCamera({super.key});

  @override
  State<InAppPhotoCamera> createState() => _InAppPhotoCameraState();
}

class _InAppPhotoCameraState extends State<InAppPhotoCamera>
    with WidgetsBindingObserver {
  static const Color _accent = Color(0xFFC5A97B);

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  bool _isTaking = false;
  bool _isSwitching = false;
  FlashMode _flash = FlashMode.off;
  // Olingan rasm — null bo'lmasa tasdiqlash ("Qayta olish" / "OK") ko'rinadi.
  XFile? _captured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('Kamera topilmadi');
        return;
      }
      await _openCamera(_backCameraIndex());
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      _showError('Kamera xatosi: $e');
    }
  }

  int _backCameraIndex() {
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.back) return i;
    }
    return 0;
  }

  int _frontCameraIndex() {
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.front) return i;
    }
    return 0;
  }

  Future<void> _openCamera(int index) async {
    await _controller?.dispose();
    // veryHigh (~1080p) — mahsulot/chekni ko'rish uchun yetarli sifat, fayl
    // hajmi esa to'liq o'lchamdagi rasmdan ancha kichik. Ovoz kerak emas.
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _controller = controller;
    await controller.initialize();
    try {
      await controller.setFlashMode(_flash);
    } catch (_) {
      // Ba'zi kameralarda (odatda old) flash yo'q — jim.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // camera plugin tavsiyasi: ilova fon/qulfga tushsa kamerani bo'shatish,
    // qaytganda qayta ochish (aks holda ba'zi qurilmalarda qora ekran).
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      if (controller != null && controller.value.isInitialized) {
        controller.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _openCamera(_isFrontCamera ? _frontCameraIndex() : _backCameraIndex())
          .then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isTaking) {
      return;
    }
    setState(() => _isTaking = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _captured = file;
        _isTaking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTaking = false);
      _showError('Rasm olinmadi: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 || _isSwitching) return;
    setState(() => _isSwitching = true);
    try {
      _isFrontCamera = !_isFrontCamera;
      await _openCamera(
        _isFrontCamera ? _frontCameraIndex() : _backCameraIndex(),
      );
    } catch (e) {
      _showError('Kamera almashtirilmadi: $e');
    }
    if (mounted) setState(() => _isSwitching = false);
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    setState(() => _flash = next);
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {
      // Flash qo'llanmaydigan kamera — jim.
    }
  }

  IconData get _flashIcon => switch (_flash) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        _ => Icons.flash_on,
      };

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _captured != null ? _buildConfirm() : _buildCamera(),
    );
  }

  // ── Kamera ko'rinishi: preview + yopish/flash + tushirish/aylantirish ──
  Widget _buildCamera() {
    final controller = _controller;
    final ready = _isInitialized &&
        controller != null &&
        controller.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              // Portret rejim: previewSize yon-o'lchamlari almashadi
              // (TelegramStyleVideoRecorder bilan bir xil usul).
              width: controller.value.previewSize!.height,
              height: controller.value.previewSize!.width,
              child: CameraPreview(controller),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _roundButton(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    _roundButton(icon: _flashIcon, onTap: _toggleFlash),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    // Tushirish tugmasi.
                    GestureDetector(
                      onTap: ready && !_isTaking ? _takePicture : null,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: _isTaking
                              ? const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _cameras.length > 1
                            ? _roundButton(
                                icon: Icons.flip_camera_ios,
                                onTap: _isSwitching ? null : _toggleCamera,
                              )
                            : const SizedBox(width: 48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tasdiqlash ko'rinishi: olingan rasm + "Qayta olish" / "OK" ──
  Widget _buildConfirm() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: Image.file(File(_captured!.path))),
        SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _confirmButton(
                      icon: Icons.refresh,
                      label: 'Qayta olish',
                      background: Colors.black.withValues(alpha: 0.55),
                      onTap: () => setState(() => _captured = null),
                    ),
                    _confirmButton(
                      icon: Icons.check,
                      label: 'OK',
                      background: _accent,
                      onTap: () => Navigator.of(context).pop(_captured),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _confirmButton({
    required IconData icon,
    required String label,
    required Color background,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
