// admin/services/tech_image_upload_service.dart — тех карта baza rasmini
// yuklash servisi: TechImageUploadService.upload → POST /api/upload
// (multipart), server bergan "/static/..." URL qaytaradi.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

// Tex karta blok (baza) rasmini POST /api/upload ga multipart yuklaydi.
// Muvaffaqiyatda server bergan URL ("/static/<fayl>") qaytadi, aks holda null.
// Kategoriya bilan bog'lanmagan mustaqil yordamchi
// (naqsh: upload_image_provider.dart dagi uploadImage).
class TechImageUploadService {
  final Dio _dio = sl<Dio>();

  Future<String?> upload(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        AppUrls.upload,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final url = data['url'] ??
            data['image_url'] ??
            data['data']?['url'] ??
            data['data']?['image_url'];
        final s = url?.toString() ?? '';
        return s.isEmpty ? null : s;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
