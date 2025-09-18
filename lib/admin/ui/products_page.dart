import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uz_ai_dev/admin/model/product.dart';
import 'package:uz_ai_dev/models/user_model.dart';

import 'package:uz_ai_dev/admin/services/api_product_service.dart';
import 'package:uz_ai_dev/admin/services/api_filial_service.dart';

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
      print('products_page.error'.tr(args: [e.toString()]));
      _showErrorSnackBar('products_page.load_error'.tr(args: [e.toString()]));
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
          _showSuccessSnackBar('products_page.add_success'.tr());
        } else {
          _showErrorSnackBar('products_page.add_error'.tr());
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar(
            'products_page.add_error_detailed'.tr(args: [e.toString()]));
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
          _showSuccessSnackBar('products_page.update_success'.tr());
        } else {
          setState(() {
            isLoading = false;
          });
          _showErrorSnackBar('products_page.update_error'.tr());
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar(
            'products_page.update_error_detailed'.tr(args: [e.toString()]));
      }
    }
  }

  Future<void> _deleteProduct(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('products_page.delete_title'.tr()),
        content: Text(
          'products_page.delete_confirmation'
              .tr(namedArgs: {'name': products[index].name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('common.delete'.tr()),
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
        _showSuccessSnackBar('products_page.delete_success'.tr());
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar(
            'products_page.delete_error_detailed'.tr(args: [e.toString()]));
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
        title: Text('products_page.title'
            .tr(namedArgs: {'category': widget.categoryName})),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'common.refresh'.tr(),
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
                      Text(
                        'products_page.no_products'.tr(),
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add),
                        label: Text('products_page.add_first_product'.tr()),
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
                          "${product.name} (${product.type})",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'products_page.filials'.tr(namedArgs: {
                                'filials': product.filialNames.isNotEmpty
                                    ? product.filialNames.join(', ')
                                    : 'products_page.filials_loading'.tr()
                              }),
                              style: TextStyle(
                                color: product.filialNames.isEmpty
                                    ? Colors.grey
                                    : null,
                              ),
                            ),
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
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text('common.edit'.tr()),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text('common.delete'.tr()),
                                ],
                              ),
                            ),
                          ],
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.grey,
                          ),
                          tooltip: 'common.actions'.tr(),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'products_page.add_new_product'.tr(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ADD PRODUCT DIALOG - 100% REAL BACKEND
class AddProductDialog extends StatefulWidget {
  final int categoryId;

  const AddProductDialog({super.key, required this.categoryId});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final nameController = TextEditingController();
  final typeController = TextEditingController();
  final filialService = ApiFilialService();

  List<int> selectedFilials = [];
  List<Filial> availableFilials = [];
  bool isLoadingFilials = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFilials();
  }

  Future<void> _loadFilials() async {
    setState(() {
      isLoadingFilials = true;
      errorMessage = null;
    });

    try {
      final filials = await filialService.getFilials();
      setState(() {
        availableFilials = filials;
        isLoadingFilials = false;
      });
    } catch (e) {
      setState(() {
        isLoadingFilials = false;
        errorMessage =
            'add_product_dialog.filials_load_error'.tr(args: [e.toString()]);
      });
      print('add_product_dialog.filials_load_error'.tr(args: [e.toString()]));
    }
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
      title: Text('add_product_dialog.title'.tr()),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'add_product_dialog.product_name'.tr(),
                  border: const OutlineInputBorder(),
                  hintText: 'add_product_dialog.product_name_hint'.tr(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: InputDecoration(
                  labelText: 'add_product_dialog.type'.tr(),
                  border: const OutlineInputBorder(),
                  hintText: 'add_product_dialog.type_hint'.tr(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'add_product_dialog.filials_required'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // FILIALLAR LOADING SECTION
              if (isLoadingFilials)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text('add_product_dialog.filials_loading'.tr()),
                    ],
                  ),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _loadFilials,
                        icon: const Icon(Icons.refresh),
                        label: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                )
              else if (availableFilials.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.location_off,
                          color: Colors.grey, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'add_product_dialog.no_filials_found'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                // REAL FILIALLAR FROM BACKEND
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: availableFilials.map((filial) {
                      final isSelected = selectedFilials.contains(filial.id);
                      return CheckboxListTile(
                        title: Text(
                          filial.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        value: isSelected,
                        activeColor: Colors.blue,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedFilials.add(filial.id);
                            } else {
                              selectedFilials.remove(filial.id);
                            }
                          });
                        },
                        secondary: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${filial.id}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (selectedFilials.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'add_product_dialog.selected_filials'.tr(namedArgs: {
                      'count': selectedFilials.length.toString()
                    }),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            // VALIDATION
            if (nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('add_product_dialog.validation.name_required'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (typeController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('add_product_dialog.validation.type_required'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (selectedFilials.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'add_product_dialog.validation.filials_required'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'type': typeController.text.trim(),
              'filials': selectedFilials,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text('common.add'.tr()),
        ),
      ],
    );
  }
}

// EDIT PRODUCT DIALOG - 100% REAL BACKEND
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
  final filialService = ApiFilialService();

  List<Filial> availableFilials = [];
  bool isLoadingFilials = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.product.name);
    typeController = TextEditingController(text: widget.product.type);
    selectedFilials = List.from(widget.product.filials);
    _loadFilials();
  }

  Future<void> _loadFilials() async {
    setState(() {
      isLoadingFilials = true;
      errorMessage = null;
    });

    try {
      final filials = await filialService.getFilials();
      setState(() {
        availableFilials = filials;
        isLoadingFilials = false;
      });
    } catch (e) {
      setState(() {
        isLoadingFilials = false;
        errorMessage =
            'edit_product_dialog.filials_load_error'.tr(args: [e.toString()]);
      });
      print('edit_product_dialog.filials_load_error'.tr(args: [e.toString()]));
    }
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
      title: Text('edit_product_dialog.title'
          .tr(namedArgs: {'name': widget.product.name})),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'edit_product_dialog.product_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: InputDecoration(
                  labelText: 'edit_product_dialog.type'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'edit_product_dialog.filials_required'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // FILIALLAR LOADING SECTION
              if (isLoadingFilials)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text('edit_product_dialog.filials_loading'.tr()),
                    ],
                  ),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _loadFilials,
                        icon: const Icon(Icons.refresh),
                        label: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                )
              else if (availableFilials.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.location_off,
                          color: Colors.grey, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'edit_product_dialog.no_filials_found'.tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                // REAL FILIALLAR FROM BACKEND
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: availableFilials.map((filial) {
                      final isSelected = selectedFilials.contains(filial.id);
                      return CheckboxListTile(
                        title: Text(
                          filial.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          filial.location ?? "",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        value: isSelected,
                        activeColor: Colors.blue,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedFilials.add(filial.id);
                            } else {
                              selectedFilials.remove(filial.id);
                            }
                          });
                        },
                        secondary: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${filial.id}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (selectedFilials.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'edit_product_dialog.selected_filials'.tr(namedArgs: {
                      'count': selectedFilials.length.toString()
                    }),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            // VALIDATION
            if (nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('edit_product_dialog.validation.name_required'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (typeController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('edit_product_dialog.validation.type_required'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (selectedFilials.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'edit_product_dialog.validation.filials_required'.tr()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'type': typeController.text.trim(),
              'filials': selectedFilials,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}
