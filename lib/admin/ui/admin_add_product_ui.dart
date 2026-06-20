import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/provider/upload_image_provider.dart';

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
  final grammController = TextEditingController(text: '1');
  final bozorGrammController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int? _selectedCategoryId;
  List<int> _selectedFilials = [];
  File? _selectedImage;

  // Ombor → yuk keltiruvchi oqimi uchun yangi maydonlar
  bool _moneApp = true;
  bool _bozor = false;
  String _source = 'samarqand';
  List<int> _selectedSklads = [];

  static const Map<String, String> _sourceOptions = {
    'samarqand': 'Samarqand',
    'toshkent': 'Toshkent',
    'zagranitsa': 'Zagranitsa',
  };

  static const Map<int, String> _skladOptions = {
    1: 'Marxabo Sklat',
    2: 'Sardor Sklat',
    3: 'Fresco Sklat',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProviderAdmin>().getCategories();
      context.read<FilialProviderAdmin>().getFilials();
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
            TextFormField(
              controller: grammController,
              decoration: const InputDecoration(
                labelText: 'Mone gramm',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null; // bo‘sh bo‘lsa ruxsat
                }
                if (double.tryParse(value) == null) {
                  return "Принимаются только цифры.";
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
            // Mone app / Bozor / Yuk manbai
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mone app'),
              value: _moneApp,
              onChanged: (value) {
                setState(() {
                  _moneApp = value;
                });
              },
            ),
            // Filiallar tanlovi faqat Mone app yoqilganda ko'rinadi
            if (_moneApp)
              Consumer<FilialProviderAdmin>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                        child: CircularProgressIndicator.adaptive());
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Выберите филиалы:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
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
                      }),
                    ],
                  );
                },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bozor'),
              value: _bozor,
              onChanged: (value) {
                setState(() {
                  _bozor = value;
                });
              },
            ),
            // Bozor yoqilganda: bozor grammi, yuk manbai (radio) va sklad tanlovi (checkbox)
            if (_bozor) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: bozorGrammController,
                decoration: const InputDecoration(
                  labelText: 'Bozor gramm',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // bo‘sh bo‘lsa ruxsat
                  }
                  if (double.tryParse(value) == null) {
                    return "Принимаются только цифры.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Yuk qayerdan keladi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              RadioGroup<String>(
                groupValue: _source,
                onChanged: (value) {
                  setState(() {
                    _source = value ?? 'samarqand';
                  });
                },
                child: Column(
                  children: _sourceOptions.entries.map((entry) {
                    return RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      value: entry.key,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Qaysi skladdan buyurtma bera oladi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._skladOptions.entries.map((entry) {
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: _selectedSklads.contains(entry.key),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedSklads.add(entry.key);
                      } else {
                        _selectedSklads.remove(entry.key);
                      }
                    });
                  },
                );
              }),
            ],
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
                            if (_moneApp && _selectedFilials.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Выберите хотя бы одну ветку')),
                              );
                              return;
                            }
                            if (_bozor && _selectedSklads.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Выберите хотя бы один склад')),
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
                              grams: grammController.text.isEmpty
                                  ? null
                                  : double.parse(grammController.text),
                              bozorGrams: bozorGrammController.text.isEmpty
                                  ? null
                                  : double.parse(bozorGrammController.text),
                              ingredients: ingredientsControlle.text,
                              filials: _selectedFilials,
                              filialNames: [],
                              imageUrl: imageUrl ?? '',
                              moneApp: _moneApp,
                              bozor: _bozor,
                              source: _source,
                              sklads: _selectedSklads,
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
    ingredientsControlle.dispose();
    grammController.dispose();
    bozorGrammController.dispose();
    super.dispose();
  }
}
