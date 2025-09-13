import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/product.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/services/api_product_service.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';

class ProductsPage extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const ProductsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final apiService = ApiProductService();
  List<ProductModel> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      isLoading = true;
    });

    try {
      final fetchedProducts =
          await apiService.getProductsByCategoryId(widget.categoryId);
      setState(() {
        products = fetchedProducts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Xatolik: $e');
      _showErrorSnackBar('Mahsulotlarni yuklashda xatolik: $e');
    }
  }

  Future<void> _addProduct() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddProductDialog(categoryId: widget.categoryId),
    );

    if (result != null) {
      setState(() {
        isLoading = true;
      });

      try {
        final newProduct = ProductModel(
          id: 0,
          name: result['name'],
          categoryId: widget.categoryId,
          type: result['type'],
          categoryName: widget.categoryName,
          filials: result['filials'],
          filialNames: [], // Server tomonidan to'ldiriladi
        );

        final createdProduct = await apiService.createProduct(newProduct);

        if (createdProduct.id != 0) {
          await _loadProducts();
          _showSuccessSnackBar('Mahsulot muvaffaqiyatli qo\'shildi!');
        } else {
          _showErrorSnackBar('Mahsulot qo\'shishda xatolik yuz berdi');
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Mahsulot qo\'shishda xatolik: $e');
      }
    }
  }

  Future<void> _editProduct(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditProductDialog(product: products[index]),
    );

    if (result != null) {
      setState(() {
        isLoading = true;
      });

      try {
        final updatedProduct = products[index].copyWith(
          name: result['name'],
          type: result['type'],
          filials: result['filials'],
        );

        final updated = await apiService.updateProduct(updatedProduct);

        if (updated.id != 0) {
          await _loadProducts();
          _showSuccessSnackBar('Mahsulot muvaffaqiyatli yangilandi!');
        } else {
          setState(() {
            isLoading = false;
          });
          _showErrorSnackBar('Mahsulot yangilashda xatolik yuz berdi');
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Mahsulot yangilashda xatolik: $e');
      }
    }
  }

  Future<void> _deleteProduct(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mahsulotni o\'chirish'),
        content: Text(
          'Haqiqatan ham "${products[index].name}" mahsulotini o\'chirmoqchimisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isLoading = true;
      });

      try {
        await apiService.deleteProduct(products[index]);
        await _loadProducts();
        _showSuccessSnackBar('Mahsulot muvaffaqiyatli o\'chirildi!');
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Mahsulot o\'chirishda xatolik: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} - Mahsulotlar'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Yangilash',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.inventory_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bu kategoriyada mahsulot yo\'q',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('Birinchi mahsulot qo\'shing'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${product.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Turi: ${product.type}'),
                            Text(
                                'Filiallar: ${product.filialNames.join(', ')}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editProduct(index);
                            } else if (value == 'delete') {
                              _deleteProduct(index);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Tahrirlash'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('O\'chirish'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Yangi mahsulot qo\'shish',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddProductDialog extends StatefulWidget {
  final int categoryId;

  const AddProductDialog({super.key, required this.categoryId});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final nameController = TextEditingController();
  final typeController = TextEditingController();
  List<int> selectedFilials = [];

  // Mock filials data - real dasturda APIdan keladi
  final List<Map<String, dynamic>> mockFilials = [
    {'id': 1, 'name': 'Гелион'},
    {'id': 2, 'name': 'Сибирские пелемени'},
    {'id': 3, 'name': 'Мархабо'},
    {'id': 4, 'name': 'Fresco'},
  ];

  @override
  void dispose() {
    nameController.dispose();
    typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yangi mahsulot qo\'shish'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Mahsulot nomi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(
                labelText: 'Turi (шт, кг, л)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Filiallar:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...mockFilials.map((filial) {
              return CheckboxListTile(
                title: Text(filial['name']),
                value: selectedFilials.contains(filial['id']),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedFilials.add(filial['id']);
                    } else {
                      selectedFilials.remove(filial['id']);
                    }
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        TextButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty &&
                typeController.text.trim().isNotEmpty &&
                selectedFilials.isNotEmpty) {
              Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'type': typeController.text.trim(),
                'filials': selectedFilials,
              });
            }
          },
          child: const Text('Qo\'shish'),
        ),
      ],
    );
  }
}

class EditProductDialog extends StatefulWidget {
  final ProductModel product;

  const EditProductDialog({super.key, required this.product});

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late TextEditingController nameController;
  late TextEditingController typeController;
  late List<int> selectedFilials;

  // Mock filials data
  final List<Map<String, dynamic>> mockFilials = [
    {'id': 1, 'name': 'Гелион'},
    {'id': 2, 'name': 'Сибирские пелемени'},
    {'id': 3, 'name': 'Мархабо'},
    {'id': 4, 'name': 'Fresco'},
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.product.name);
    typeController = TextEditingController(text: widget.product.type);
    selectedFilials = List.from(widget.product.filials);
  }

  @override
  void dispose() {
    nameController.dispose();
    typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mahsulotni tahrirlash'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Mahsulot nomi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(
                labelText: 'Turi (шт, кг, л)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Filiallar:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...mockFilials.map((filial) {
              return CheckboxListTile(
                title: Text(filial['name']),
                value: selectedFilials.contains(filial['id']),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedFilials.add(filial['id']);
                    } else {
                      selectedFilials.remove(filial['id']);
                    }
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        TextButton(
          onPressed: () {
            if (nameController.text.trim().isNotEmpty &&
                typeController.text.trim().isNotEmpty &&
                selectedFilials.isNotEmpty) {
              Navigator.of(context).pop({
                'name': nameController.text.trim(),
                'type': typeController.text.trim(),
                'filials': selectedFilials,
              });
            }
          },
          child: const Text('Saqlash'),
        ),
      ],
    );
  }
}
