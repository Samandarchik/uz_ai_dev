import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:uz_ai_dev/admin_agent/model/category_model.dart';
import 'package:uz_ai_dev/admin_agent/services/admin_categoriy.dart';

import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/agent/urls.dart';
class CategoryProviderAdminAgentUpload extends ChangeNotifier {
  final ApiAdminService _service = ApiAdminService();
  final Dio _dio = sl<Dio>(); // Dio();
  final String baseUrl = AppUrlsAgent.baseUrl; // Replace with your base URL

  List<CategoryProductAdmin> _categories = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  CategoryProductAdmin? _selectedCategory;
  double _uploadProgress = 0.0;

  // Getters
  List<CategoryProductAdmin> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  CategoryProductAdmin? get selectedCategory => _selectedCategory;
  double get uploadProgress => _uploadProgress;

  // Upload image to /api/upload using Dio
  Future<String?> uploadImage(File imageFile) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      print('📤 Starting image upload...');
      print('📁 File path: ${imageFile.path}');
      print('📊 File size: ${await imageFile.length()} bytes');

      // Create FormData
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      print('🌐 Upload URL: $baseUrl/api/upload');

      // Send request with progress tracking
      final response = await _dio.post(
        '$baseUrl/api/upload',
        data: formData,
        onSendProgress: (sent, total) {
          _uploadProgress = sent / total;
          print(
            '📈 Upload progress: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
          );
          notifyListeners();
        },
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📦 Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final imageUrl = response.data['url'] ??
            response.data['image_url'] ??
            response.data['data']?['url'] ??
            response.data['data']?['image_url'];

        if (imageUrl == null) {
          print('❌ Image URL not found in response');
          print('📦 Full response: ${response.data}');
          throw Exception('Image URL not found in response');
        }

        print('✅ Upload successful! Image URL: $imageUrl');

        _isUploading = false;
        _uploadProgress = 1.0;
        notifyListeners();

        return imageUrl;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        print('📦 Response: ${response.data}');
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.data}',
        );
      }
    } on DioException catch (e) {
      print('❌ DioException occurred:');
      print('Type: ${e.type}');
      print('Message: ${e.message}');
      print('Response: ${e.response?.data}');
      print('Status Code: ${e.response?.statusCode}');

      _error = 'Upload failed: ${e.message}';
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return null;
    } catch (e, stackTrace) {
      print('❌ Unexpected error during upload:');
      print('Error: $e');
      print('StackTrace: $stackTrace');

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
      print('🏗️ Creating category: ${category.name}');

      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        print('📸 Image file provided, uploading...');
        imageUrl = await uploadImage(imageFile);
        if (imageUrl == null) {
          print('❌ Image upload failed');
          throw Exception('Failed to upload image');
        }
        print('✅ Image uploaded successfully: $imageUrl');
      }

      // Create category with uploaded image URL
      final categoryWithImage = CategoryProductAdmin(
        id: category.id,
        name: category.name,
        printerId: category.printerId,
        imageUrl: imageUrl ?? category.imageUrl,
      );

      print('💾 Saving category to database...');
      final newCategory = await _service.createCategory(categoryWithImage);
      _categories.add(newCategory);
      _isLoading = false;
      notifyListeners();

      print('✅ Category created successfully: ${newCategory.name}');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error creating category:');
      print('Error: $e');
      print('StackTrace: $stackTrace');

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
      print('✏️ Updating category: ${category.name}');

      String? uploadedImageUrl;

      // Upload new image if provided
      if (imageFile != null) {
        print('📸 New image file provided, uploading...');
        uploadedImageUrl = await uploadImage(imageFile);
        if (uploadedImageUrl == null) {
          print('❌ Image upload failed');
          throw Exception('Failed to upload image');
        }
        print('✅ Image uploaded successfully: $uploadedImageUrl');
      }

      // Create updated category object with new values
      final updatedCategory = CategoryProductAdmin(
        id: category.id,
        name: newName ?? category.name,
        printerId: newPrint ?? category.printerId,
        imageUrl: uploadedImageUrl ?? newImageUrl ?? category.imageUrl,
      );

      print('💾 Updating category in database...');
      // Call API service
      final result = await _service.updateCategory(updatedCategory);

      // Update local list
      final index = _categories.indexWhere((c) => c.id == result.id);
      if (index != -1) {
        _categories[index] = result;

        // Update selected category if it's the one being updated
        if (_selectedCategory?.id == result.id) {
          _selectedCategory = result;
        }
      }

      _isLoading = false;
      notifyListeners();

      print('✅ Category updated successfully');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error updating category:');
      print('Error: $e');
      print('StackTrace: $stackTrace');

      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Quick update methods for specific fields
  Future<bool> updateCategoryName(int categoryId, String newName) async {
    final category = _categories.firstWhere((c) => c.id == categoryId);
    return await updateCategory(category, newName: newName);
  }

  Future<bool> updateCategoryPrint(int categoryId, int newPrint) async {
    final category = _categories.firstWhere((c) => c.id == categoryId);
    return await updateCategory(category, newPrint: newPrint);
  }

  Future<bool> updateCategoryImage(int categoryId, File imageFile) async {
    final category = _categories.firstWhere((c) => c.id == categoryId);
    return await updateCategory(category, imageFile: imageFile);
  }

  Future<bool> updateCategoryImageUrl(int categoryId, String imageUrl) async {
    final category = _categories.firstWhere((c) => c.id == categoryId);
    return await updateCategory(category, newImageUrl: imageUrl);
  }

  // Delete category
  Future<bool> deleteCategory(CategoryProductAdmin category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.deleteCategory(category);
      _categories.removeWhere((c) => c.id == category.id);

      // Clear selected category if it was deleted
      if (_selectedCategory?.id == category.id) {
        _selectedCategory = null;
      }

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

  // Get category by ID
  Future<CategoryProductAdmin?> getCategoryById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final category = await _service.getCategoryById(id);
      _selectedCategory = category;
      _isLoading = false;
      notifyListeners();
      return category;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Set selected category
  void setSelectedCategory(CategoryProductAdmin? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Refresh single category
  Future<void> refreshCategory(int categoryId) async {
    try {
      final category = await _service.getCategoryById(categoryId);
      if (category != null) {
        final index = _categories.indexWhere((c) => c.id == categoryId);
        if (index != -1) {
          _categories[index] = category;
          if (_selectedCategory?.id == categoryId) {
            _selectedCategory = category;
          }
          notifyListeners();
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data
  void clear() {
    _categories = [];
    _selectedCategory = null;
    _error = null;
    _isLoading = false;
    _isUploading = false;
    _uploadProgress = 0.0;
    notifyListeners();
  }
}
