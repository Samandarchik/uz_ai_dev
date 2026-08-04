// core/widgets/app_network_image.dart — tarmoqdagi rasmni EKRANDAGI o'lchamida
// dekod qiladigan umumiy widget (CachedNetworkImage ustiga yupqa qatlam).
//
// NEGA KERAK: backend yuklangan rasmni 1024px kenglikda saqlaydi (main.go
// resize). CachedNetworkImage'ga o'lcham berilmasa Flutter uni TO'LIQ
// 1024px'da dekod qiladi va RAM'da ~3 MB bitmap ushlab turadi — 165px'lik
// grid kartochkasi uchun ham, 55px'lik avatar uchun ham bir xil 3 MB.
//
// Flutter'ning global ImageCache limiti 100 MB: ~32 ta shunday rasm keshni
// to'ldiradi. Undan keyin har scroll'da eski rasm keshdan chiqarilib qaytadan
// dekod qilinadi (JPEG decode + GPU texture upload) va Android GC bosim
// ostida qoladi — ekran «qotib qolgandek» sezilaadi.
//
// Bu widget LayoutBuilder orqali haqiqiy kenglikni oladi, uni qurilma piksel
// zichligiga (devicePixelRatio) ko'paytiradi va `memCacheWidth` sifatida
// beradi. 165dp kartochka 3x ekranda 495px'da dekod bo'ladi — 1024px o'rniga,
// ya'ni RAM ~4 barobar kam, sifat esa ko'z ilg'amas darajada bir xil.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// `CircleAvatar.backgroundImage` kabi `ImageProvider` talab qiladigan joylar
/// uchun — vidjet emas, PROVIDER qaytaradi, lekin dekod o'lchami baribir
/// ekrandagi o'lchamga bog'lanadi.
///
/// NEGA: `CircleAvatar(backgroundImage: NetworkImage(url))` rasmni TO'LIQ
/// (1024px, ~4 MB) dekod qiladi — 52px'lik avatar uchun ham. Magazinlar
/// ro'yxatida 50 ta avatar = 200 MB → ilova o'ladi.
///
/// [displayWidth] — avatarning ekrandagi kengligi (dp): radius*2.
ImageProvider appNetworkImageProvider(
  BuildContext context,
  String url, {
  required double displayWidth,
  int maxDecodeWidth = 1024,
}) {
  return ResizeImage.resizeIfNeeded(
    _decodePx(context, displayWidth, maxDecodeWidth),
    null,
    CachedNetworkImageProvider(url),
  );
}

/// Lokal fayl uchun ayni shu (kameradan olingan rasm 4000px bo'lishi mumkin —
/// o'lchamsiz dekod qilinsa bitta rasm 48 MB RAM egallaydi).
ImageProvider appFileImageProvider(
  BuildContext context,
  String path, {
  required double displayWidth,
  int maxDecodeWidth = 1024,
}) {
  return ResizeImage.resizeIfNeeded(
    _decodePx(context, displayWidth, maxDecodeWidth),
    null,
    FileImage(File(path)),
  );
}

int _decodePx(BuildContext context, double displayWidth, int maxDecodeWidth) =>
    (displayWidth * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(16, maxDecodeWidth);

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.maxDecodeWidth = 1024,
  });

  final String imageUrl;
  final BoxFit fit;

  /// `null` bo'lsa oddiy kulrang fon ko'rsatiladi.
  final WidgetBuilder? placeholder;

  /// `null` bo'lsa «rasm yo'q» ikonkasi ko'rsatiladi.
  final WidgetBuilder? errorWidget;

  final double? width;
  final double? height;

  /// Dekod kengligining shifti (fizik piksel). Manba fayl 1024px bo'lgani
  /// uchun undan kattasini so'rashning ma'nosi yo'q.
  final int maxDecodeWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);

        // Mantiqiy kenglik: avval aniq berilgan `width`, bo'lmasa
        // LayoutBuilder bergan chegara. `double.infinity` (juda ko'p joyda
        // shunday beriladi) ham, chegarasiz constraint ham yaroqsiz —
        // bunday holda shiftni ishlatamiz.
        double? logicalWidth;
        if (width != null && width!.isFinite && width! > 0) {
          logicalWidth = width;
        } else if (constraints.hasBoundedWidth && constraints.maxWidth > 0) {
          logicalWidth = constraints.maxWidth;
        }

        final memCacheWidth = logicalWidth == null
            ? maxDecodeWidth
            : (logicalWidth * dpr).round().clamp(16, maxDecodeWidth);

        return CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: memCacheWidth,
          // Diskda ham shu o'lchamdan kattasini saqlashning hojati yo'q,
          // lekin manba allaqachon 1024px — shift bilan bir xil bo'lsa
          // qayta siqish xarajati bekorga ketadi, shuning uchun tegilmaydi.
          placeholder: placeholder == null
              ? (context, url) => Container(color: Colors.grey.shade200)
              : (context, url) => placeholder!(context),
          errorWidget: errorWidget == null
              ? (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.grey, size: 30),
                  )
              : (context, url, error) => errorWidget!(context),
        );
      },
    );
  }
}
