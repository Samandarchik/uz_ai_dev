import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin_agent/model/category_model.dart';
import 'package:uz_ai_dev/admin_agent/services/upload_image.dart';

class CategoryDialog extends StatefulWidget {
  final CategoryProductAdmin? category;

  const CategoryDialog({Key? key, this.category}) : super(key: key);

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _printController;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _printController = TextEditingController(
      text: widget.category?.printerId.toString() ?? '1',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _printController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = context.read<CategoryProviderAdminAgentUpload>();
    bool success;

    if (isEditing) {
      success = await provider.updateCategory(
        widget.category!,
        newName: _nameController.text.trim(),
        newPrint: int.parse(_printController.text),
        imageFile: _selectedImage,
      );
    } else {
      success = await provider.createCategory(
        CategoryProductAdmin(
          id: 0,
          name: _nameController.text.trim(),
          printerId: int.parse(_printController.text),
          imageUrl: null,
        ),
        imageFile: _selectedImage,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Category updated' : 'Category created'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Operation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Редактировать категорию' : 'Создать категорию',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : widget.category?.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  "${AppUrls.baseUrl}${widget.category!.imageUrl!}",
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Нажмите, чтобы выбрать изображение',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название категории',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите название категории';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _printController,
                  decoration: const InputDecoration(
                    labelText: 'Распечатать значение',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.print),
                  ),
                  keyboardType: TextInputType.numberWithOptions(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Пожалуйста, введите значение для печати';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Пожалуйста, введите действительный номер';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Consumer<CategoryProviderAdminAgentUpload>(
                  builder: (context, provider, child) {
                    if (provider.isUploading) {
                      return Column(
                        children: [
                          LinearProgressIndicator(
                            value: provider.uploadProgress,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Загрузка изображения... ${(provider.uploadProgress * 100).toInt()}%',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isEditing ? 'Обновлять' : 'Создавать'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
