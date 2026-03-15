import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/provider/upload_image_provider.dart';
import 'package:uz_ai_dev/bringer/models/bringer_models.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final ingredientsControlle = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int? _selectedCategoryId;
  int? _selectedBringerId;
  List<int> _selectedFilials = [];
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProviderAdmin>().getCategories();
      context.read<FilialProviderAdmin>().getFilials();
      context.read<BringerProvider>().loadProfiles();
    });
  }

  void _showBringerSelectionDialog(List<BringerProfile> profiles) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bringerni tanlang',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.grey),
              ),
              title: const Text('Tanlanmagan'),
              trailing: _selectedBringerId == null
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                setState(() {
                  _selectedBringerId = null;
                });
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: profiles.length,
                itemBuilder: (_, index) {
                  final profile = profiles[index];
                  final isSelected = _selectedBringerId == profile.id;
                  return ListTile(
                    leading: ClipOval(
                      child: profile.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: "${AppUrls.baseUrl}${profile.imageUrl}",
                              width: 45,
                              height: 45,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 45,
                                height: 45,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.person),
                              ),
                            )
                          : Container(
                              width: 45,
                              height: 45,
                              color: Colors.blue.shade100,
                              child: const Icon(Icons.person, color: Colors.blue),
                            ),
                    ),
                    title: Text(
                      profile.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(profile.phone),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedBringerId = profile.id;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
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
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора изображения: $e')),
        );
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
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при фотосъемке: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выбор изображения'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Из галереи'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Из камеры'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый продукт'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image picker section
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: _selectedImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.red,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 50, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Выбор изображения',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload progress indicator
            Consumer<CategoryProviderAdminUpload>(
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
                labelText: 'Тип (например: шт., литры, кг)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите тип';
                }
                return null;
              },
            ),
            SizedBox(
              height: 20,
            ),
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
            Consumer<CategoryProviderAdmin>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                      child: CircularProgressIndicator.adaptive());
                }
                return DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Kategoriya',
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
                      _selectedCategoryId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Выберите категорию';
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer<FilialProviderAdmin>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                      child: CircularProgressIndicator.adaptive());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выберите филиалы:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...provider.filials.map((filial) {
                      return CheckboxListTile(
                        title: Text(filial.name),
                        value: _selectedFilials.contains(filial.id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFilials.add(filial.id);
                            } else {
                              _selectedFilials.remove(filial.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                );
              },
            ),
            // Bringer tanlash
            const SizedBox(height: 16),
            Consumer<BringerProvider>(
              builder: (context, bringerProvider, child) {
                if (bringerProvider.isLoading && bringerProvider.profiles.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bringer (olib keluvchi):',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showBringerSelectionDialog(bringerProvider.profiles),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedBringerId != null
                                    ? bringerProvider.profiles
                                        .where((p) => p.id == _selectedBringerId)
                                        .map((p) => p.name)
                                        .firstOrNull ?? 'Tanlang'
                                    : 'Tanlanmagan',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _selectedBringerId != null
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (_selectedBringerId != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _selectedBringerId = null;
                                  });
                                },
                              ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Consumer<CategoryProviderAdminUpload>(
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
                            if (_selectedFilials.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Выберите хотя бы одну ветку')),
                              );
                              return;
                            }

                            String? imageUrl;

                            // Upload image if selected
                            if (_selectedImage != null) {
                              imageUrl = await uploadProvider
                                  .uploadImage(_selectedImage!);

                              if (imageUrl == null) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Произошла ошибка при загрузке изображения.')),
                                  );
                                }
                                return;
                              }
                            }

                            final product = ProductModelAdmin(
                              id: 0,
                              name: _nameController.text,
                              categoryId: _selectedCategoryId!,
                              type: _typeController.text,
                              categoryName: '',
                              ingredients: ingredientsControlle.text,
                              filials: _selectedFilials,
                              filialNames: [],
                              imageUrl: imageUrl ?? '',
                              bringerId: _selectedBringerId,
                            );

                            final success = await context
                                .read<ProductProviderAdmin>()
                                .createProduct(product);

                            if (success && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Продукт добавлен')),
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
                      : const Text('Сохранять', style: TextStyle(fontSize: 16)),
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
    super.dispose();
  }
}
