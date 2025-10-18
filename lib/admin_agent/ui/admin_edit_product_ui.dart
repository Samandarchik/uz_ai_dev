// ==================== EDIT PRODUCT PAGE WITH IMAGE UPLOAD ====================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uz_ai_dev/core/agent/urls.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin_agent/model/product_model.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin_agent/services/upload_image.dart';

class EditProductPage extends StatefulWidget {
  final ProductModelAdmin product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController ingredientsControlle;
  late int _selectedCategoryId;
  late List<int> _selectedFilials;

  File? _selectedImage;
  bool _imageChanged = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _typeController = TextEditingController(text: widget.product.type);
    ingredientsControlle = TextEditingController(
      text: widget.product.ingredients,
    );
    _selectedCategoryId = widget.product.categoryId;
    _selectedFilials = List.from(widget.product.filials);
    _currentImageUrl = widget.product.imageUrl;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProviderAdminAgent>().getCategories();
      context.read<FilialProviderAdminAgent>().getFilials();
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _imageChanged = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rasm tanlashda Ошибка: $e')));
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _imageChanged = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rasm olishda Ошибка: $e')));
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rasm tanlash'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galereyadan'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kameradan'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _currentImageUrl = null;
      _imageChanged = true;
    });
  }

  Widget _buildImageWidget() {
    // Yangi rasm tanlangan bo'lsa
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _selectedImage!,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        ),
      );
    }

    // Mavjud rasm bor bo'lsa
    if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      // Base URL qo'shish
      final String fullImageUrl = _currentImageUrl!.startsWith('http')
          ? _currentImageUrl!
          : '${AppUrlsAgent.baseUrl}$_currentImageUrl';

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fullImageUrl,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator.adaptive(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      );
    }

    // Rasm yo'q bo'lsa
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text('Rasm tanlash', style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование продукта')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image section
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    Center(child: _buildImageWidget()),
                    if (_selectedImage != null ||
                        (_currentImageUrl != null &&
                            _currentImageUrl!.isNotEmpty))
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.red,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _removeImage,
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload progress indicator
            Consumer<CategoryProviderAdminAgentUpload>(
              builder: (context, provider, child) {
                if (provider.isUploading) {
                  return Column(
                    children: [
                      LinearProgressIndicator(value: provider.uploadProgress),
                      const SizedBox(height: 8),
                      Text(
                        'Загрузка: ${(provider.uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название продукта',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите название продукта';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Тип',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите тип';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: ingredientsControlle,
              decoration: const InputDecoration(
                labelText: 'Состав',
                border: OutlineInputBorder(),
                alignLabelWithHint: true, // label pastga joylashsin
              ),
              keyboardType: TextInputType.multiline, // ko‘p qatorli matn uchun
              maxLines: null, // cheklanmagan qatorlar
              textInputAction:
                  TextInputAction.newline, // Enter yangi qator ochadi
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Писать Состав';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Consumer<CategoryProviderAdminAgent>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                return DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * .7,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value!;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Consumer<CategoryProviderAdminAgentUpload>(
              builder: (context, uploadProvider, child) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: uploadProvider.isUploading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            String? imageUrl = _currentImageUrl;

                            // Upload new image if changed
                            if (_imageChanged && _selectedImage != null) {
                              final uploadedUrl = await uploadProvider
                                  .uploadImage(_selectedImage!);

                              if (uploadedUrl == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Произошла ошибка при загрузке изображения.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              imageUrl = uploadedUrl;
                            } else if (_imageChanged &&
                                _selectedImage == null) {
                              // Image was removed
                              imageUrl = '';
                            }

                            final updatedProduct = widget.product.copyWith(
                              name: _nameController.text,
                              categoryId: _selectedCategoryId,
                              type: _typeController.text,
                              ingredients: ingredientsControlle.text,
                              filials: _selectedFilials,
                              imageUrl: imageUrl,
                            );

                            final success = await context
                                .read<ProductProviderAgentAdmin>()
                                .updateProduct(updatedProduct);

                            if (success && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Продукт обновлен'),
                                ),
                              );
                            }
                          }
                        },
                  child: uploadProvider.isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Обновлять', style: TextStyle(fontSize: 16)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    ingredientsControlle.dispose();
    super.dispose();
  }
}
