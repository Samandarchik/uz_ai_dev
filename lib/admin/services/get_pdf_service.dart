import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class ApiPdfService {
  final Dio _simpleDio = sl<Dio>();

  Future<String> downloadCategoryPdf(
    int categoryId, {
    Function(int received, int total)? onProgress,
  }) async {
    final main = Stopwatch()..start();

    debugPrint("🚀 START PDF DOWNLOAD: $categoryId");

    // TEMP directory
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/category_$categoryId.pdf';
    final file = File(filePath);

    // Agar fayl mavjud bo'lsa, avval o'chirish
    if (await file.exists()) {
      await file.delete();
      debugPrint("🗑️ Old PDF deleted");
    }

    // Request setup (STREAM MODE)
    try {
      final response = await _simpleDio.post(
        '${AppUrls.baseUrl}/api/products/category/$categoryId/pdf',
        options: Options(responseType: ResponseType.stream),
      );

      final contentLength =
          response.headers.value(Headers.contentLengthHeader) ?? "0";
      final total = int.tryParse(contentLength) ?? 0;

      debugPrint("📦 Content-Length: $total bytes");

      // STREAM WRITER
      final sink = file.openWrite();

      num received = 0;

      await response.data.stream.listen(
        (chunk) {
          received += chunk.length;
          sink.add(chunk);

          if (onProgress != null) {
            onProgress(received.toInt(), total);
          }

          if (total > 0) {
            final progress = (received / total * 100).toInt();
            if (progress % 25 == 0) {
              debugPrint("⬇️ Progress: $progress%");
            }
          }
        },
      ).asFuture();

      await sink.close();

      debugPrint("✅ File saved → $filePath");
      debugPrint("⏱ TOTAL TIME: ${main.elapsedMilliseconds} ms");

      return filePath;
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      throw Exception("PDF yuklab bo'lmadi");
    }
  }

  // Download va Share birga
  Future<void> downloadAndSharePdf(
    int categoryId, {
    Function(int received, int total)? onProgress,
    String? shareText,
  }) async {
    final main = Stopwatch()..start();

    debugPrint("🚀 START PDF DOWNLOAD & SHARE: $categoryId");

    try {
      // 1. Download
      final filePath = await downloadCategoryPdf(
        categoryId,
        onProgress: onProgress,
      );

      // 2. Share
      final shareStopwatch = Stopwatch()..start();
      debugPrint("📤 Sharing PDF...");

      final xFile = XFile(filePath);
      await SharePlus.instance.share(ShareParams(
        files: [xFile],
        text: shareText ?? 'Mahsulot katalogi',
        subject: 'PDF Katalog',
      ));

      shareStopwatch.stop();
      debugPrint("✅ Share dialog opened");
      debugPrint("⏱ Share time: ${shareStopwatch.elapsedMilliseconds} ms");

      main.stop();
      debugPrint("⏱ TOTAL TIME (with share): ${main.elapsedMilliseconds} ms");
    } catch (e) {
      debugPrint("❌ ERROR in downloadAndSharePdf: $e");
      throw Exception("PDF yuklash yoki ulashishda xatolik");
    }
  }

  // Eski PDF fayllarini tozalash
  Future<void> cleanupOldPdfs() async {
    try {
      final directory = await getTemporaryDirectory();
      final dir = Directory(directory.path);

      final files = dir.listSync();
      for (var file in files) {
        if (file is File &&
            file.path.contains('category_') &&
            file.path.endsWith('.pdf')) {
          await file.delete();
          debugPrint("🗑️ Deleted old PDF: ${file.path}");
        }
      }

      debugPrint("✅ Cleanup completed");
    } catch (e) {
      debugPrint("⚠️ Cleanup error: $e");
      // Xatolikni ignore qilamiz, chunki bu critical emas
    }
  }

  // Muayyan kategoriya PDF faylini o'chirish
  Future<void> deleteCategoryPdf(int categoryId) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/category_$categoryId.pdf';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        debugPrint("🗑️ Deleted PDF for category $categoryId");
      }
    } catch (e) {
      debugPrint("⚠️ Delete error: $e");
    }
  }
}
