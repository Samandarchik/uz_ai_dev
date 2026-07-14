import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/admin/model/category_model.dart';
import 'package:uz_ai_dev/admin/services/admin_categoriy.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class CategoryProviderAdminUpload extends ChangeNotifier {
  final ApiAdminService _service = ApiAdminService();
  final Dio _dio = sl<Dio>(); // Dio();
  final String baseUrl = AppUrls.baseUrl; // Replace with your base URL

  List<CategoryProductAdmin> _categories = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  double _uploadProgress = 0.0;

  // Getters
  List<CategoryProductAdmin> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  double get uploadProgress => _uploadProgress;

  // Upload image to /api/upload using Dio
  Future<String?> uploadImage(File imageFile) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {

      // Create FormData
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });


      // Send request with progress tracking
      final response = await _dio.post(
        '$baseUrl/api/upload',
        data: formData,
        onSendProgress: (sent, total) {
          _uploadProgress = sent / total;
          notifyListeners();
        },
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final imageUrl = response.data['url'] ??
            response.data['image_url'] ??
            response.data['data']?['url'] ??
            response.data['data']?['image_url'];

        if (imageUrl == null) {
          throw Exception('Image URL not found in response');
        }

        _isUploading = false;
        _uploadProgress = 1.0;
        notifyListeners();

        return imageUrl;
      } else {
        throw Exception(
            'Upload failed: ${response.statusCode} - ${response.data}');
      }
    } on DioException catch (e) {
      _error = 'Upload failed: ${e.message}';
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return null;
    } catch (e, _) {

      _error = 'Upload failed: ${e.toString()}';
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return null;
    }
  }

  // Get all categories
  Future<void> getCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _service.getCategories();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new category with image upload
  Future<bool> createCategory(
    CategoryProductAdmin category, {
    File? imageFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🏗️ Creating category: ${category.name}');

      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        debugPrint('📸 Image file provided, uploading...');
        imageUrl = await uploadImage(imageFile);
        if (imageUrl == null) {
          debugPrint('❌ Image upload failed');
          throw Exception('Failed to upload image');
        }
        debugPrint('✅ Image uploaded successfully: $imageUrl');
      }

      // Create category with uploaded image URL
      final categoryWithImage = CategoryProductAdmin(
        id: category.id,
        name: category.name,
        printerId: category.printerId,
        imageUrl: imageUrl ?? category.imageUrl,
      );

      debugPrint('💾 Saving category to database...');
      final newCategory = await _service.createCategory(categoryWithImage);
      _categories.add(newCategory);
      _isLoading = false;
      notifyListeners();

      debugPrint('✅ Category created successfully: ${newCategory.name}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating category:');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');

      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update existing category with optional image upload
  Future<bool> updateCategory(
    CategoryProductAdmin category, {
    String? newName,
    int? newPrint,
    String? newImageUrl,
    File? imageFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('✏️ Updating category: ${category.name}');

      String? uploadedImageUrl;

      // Upload new image if provided
      if (imageFile != null) {
        debugPrint('📸 New image file provided, uploading...');
        uploadedImageUrl = await uploadImage(imageFile);
        if (uploadedImageUrl == null) {
          debugPrint('❌ Image upload failed');
          throw Exception('Failed to upload image');
        }
        debugPrint('✅ Image uploaded successfully: $uploadedImageUrl');
      }

      // Create updated category object with new values
      final updatedCategory = CategoryProductAdmin(
        id: category.id,
        name: newName ?? category.name,
        printerId: newPrint ?? category.printerId,
        imageUrl: uploadedImageUrl ?? newImageUrl ?? category.imageUrl,
      );

      debugPrint('💾 Updating category in database...');
      // Call API service
      final result = await _service.updateCategory(updatedCategory);

      // Update local list
      final index = _categories.indexWhere((c) => c.id == result.id);
      if (index != -1) {
        _categories[index] = result;
      }

      _isLoading = false;
      notifyListeners();

      debugPrint('✅ Category updated successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating category:');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');

      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete category
  Future<bool> deleteCategory(CategoryProductAdmin category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.deleteCategory(category);
      _categories.removeWhere((c) => c.id == category.id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

}
