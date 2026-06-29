import 'package:easy_video_editor/easy_video_editor.dart';

/// Telegram "video note" uslubidagi qayta ishlash:
///  - bir nechta segment bo'lsa, ularni bitta videoga birlashtiradi;
///  - markazdan KVADRAT (1:1) qirqadi — ekranda aylana ko'rinishda chiqadi;
///  - 480p ga siqadi (kichik hajm, sifat saqlanadi).
///
/// FFmpeg ishlatmaydi: iOS'da AVFoundation, Android'da MediaCodec.
/// Yangi (qayta ishlangan) faylning yo'lini qaytaradi.
class VideoProcessor {
  /// [segmentPaths] — rekorder qaytargan lokal video fayl yo'llari.
  /// Kamida bitta yo'l bo'lishi shart.
  /// [onProgress] — 0.0..1.0 oralig'ida export jarayoni (ixtiyoriy).
  static Future<String> toSquareNote(
    List<String> segmentPaths, {
    void Function(double progress)? onProgress,
  }) async {
    if (segmentPaths.isEmpty) {
      throw ArgumentError('segmentPaths bo\'sh bo\'lishi mumkin emas');
    }

    // 1) Birlashtirish: bitta segment bo'lsa o'sha bilan boshlaymiz,
    //    bir nechta bo'lsa merge qilamiz.
    var builder = VideoEditorBuilder(videoPath: segmentPaths.first);
    if (segmentPaths.length > 1) {
      builder = builder.merge(otherVideoPaths: segmentPaths.sublist(1));
    }

    // 2) Kvadrat qirqish + 480p ga siqish.
    final outputPath = await builder
        .crop(aspectRatio: VideoAspectRatio.ratio1x1)
        .compress(resolution: VideoResolution.p480)
        .export(onProgress: onProgress);

    if (outputPath == null) {
      throw Exception('Videoni qayta ishlashda xatolik');
    }
    return outputPath;
  }
}
