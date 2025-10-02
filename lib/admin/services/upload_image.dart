import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/services/admin_categoriy.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';

class CategoryProviderAdminUpload extends ChangeNotifier {
  final ApiAdminService _service = ApiAdminService();
  final String baseUrl = AppUrls.baseUrl; // Replace with your base URL

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

  // Upload image to /api/upload
  Future<String?> uploadImage(File imageFile) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload'),
      );

      // Add the image file
      var multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );
      request.files.add(multipartFile);

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = json.decode(response.body);
        final imageUrl = jsonResponse['url'] ?? jsonResponse['image_url'];

        _isUploading = false;
        _uploadProgress = 1.0;
        notifyListeners();

        return imageUrl;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Image upload failed: ${e.toString()}';
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
      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile);
        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // Create category with uploaded image URL
      final categoryWithImage = CategoryProductAdmin(
        id: category.id,
        name: category.name,
        printerId: category.printerId,
        imageUrl: imageUrl ?? category.imageUrl,
      );

      final newCategory = await _service.createCategory(categoryWithImage);
      _categories.add(newCategory);
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
      String? uploadedImageUrl;

      // Upload new image if provided
      if (imageFile != null) {
        uploadedImageUrl = await uploadImage(imageFile);
        if (uploadedImageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      // Create updated category object with new values
      final updatedCategory = CategoryProductAdmin(
        id: category.id,
        name: newName ?? category.name,
        printerId: newPrint ?? category.printerId,
        imageUrl: uploadedImageUrl ?? newImageUrl ?? category.imageUrl,
      );

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
      return true;
    } catch (e) {
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

// Example usage in UI:
/*
// Create category with image
File imageFile = File('/path/to/image.jpg');
await provider.createCategory(
  CategoryProductAdmin(id: 0, name: "New Category", print: 1),
  imageFile: imageFile,
);

// Update category with new image
await provider.updateCategory(
  category,
  newName: "Updated Name",
  imageFile: imageFile,
);

// Update only image
await provider.updateCategoryImage(categoryId, imageFile);

// Listen to upload progress
Consumer<CategoryProviderAdmin>(
  builder: (context, provider, child) {
    if (provider.isUploading) {
      return CircularProgressIndicator(
        value: provider.uploadProgress,
      );
    }
    return YourWidget();
  },
)
*/
