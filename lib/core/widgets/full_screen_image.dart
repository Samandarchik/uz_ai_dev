// core/widgets/full_screen_image.dart — rasmni TO'LIQ EKRANDA ko'rish uchun
// yagona ekran: FullScreenImagePage + openFullScreenImage() qisqartmasi.
// Qora fon, pinch-zoom (InteractiveViewer), ekranga bosilsa yopiladi.
//
// NEGA ALOHIDA VIDJET: ilgari har ekran o'zicha `Image.network(url)` bilan
// dialog ochardi. Ikkita nuqsoni bor edi:
//   1) rasm O'LCHAMSIZ dekod qilinardi — 1024px rasm RAM'da ~4 MB;
//   2) yopilgandan keyin ham u ImageCache'da qolardi — ketma-ket 10 ta rasm
//      ochilsa 40 MB yig'ilib, ro'yxatdagi thumbnail'lar bilan birga ilovani
//      o'ldirardi (iOS OOM).
// Bu yerda rasm EKRAN kengligida dekod qilinadi va chiqishda AYNAN SHU rasm
// keshdan chiqariladi (`evict`) — boshqa ekranlarning rasmiga tegilmaydi.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// Rasmni to'liq ekranda ochish (barcha ekranlar shuni chaqiradi).
Future<void> openFullScreenImage(BuildContext context, String imageUrl) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => FullScreenImagePage(imageUrl: imageUrl)),
  );
}

class FullScreenImagePage extends StatefulWidget {
  const FullScreenImagePage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  ImageProvider? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_image != null) return;
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Manba fayl serverda 1024px'da saqlanadi — undan kattasini so'rashning
    // ma'nosi yo'q. Kichik ekranda esa undan ham kam dekod qilinadi.
    final decodeWidth = (size.width * dpr).round().clamp(320, 1024);
    _image = ResizeImage.resizeIfNeeded(
      decodeWidth,
      null,
      CachedNetworkImageProvider(widget.imageUrl),
    );
  }

  @override
  void dispose() {
    // Katta bitmap RAM'da qolib ketmasin.
    _image?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              SizedBox.expand(
                child: InteractiveViewer(
                  child: Center(
                    child: image == null
                        ? const SizedBox.shrink()
                        : Image(
                            image: image,
                            fit: BoxFit.contain,
                            frameBuilder:
                                (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded || frame != null) {
                                return child;
                              }
                              return const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              );
                            },
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.white38,
                              size: 48,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
