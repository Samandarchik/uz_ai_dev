import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/services/admin_categoriy.dart';
import 'package:uz_ai_dev/admin/ui/products_page.dart';
import 'package:uz_ai_dev/admin/user_management_screen.dart';
import 'package:uz_ai_dev/main.dart';
import 'package:uz_ai_dev/user/ui/screens/login_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final apiService = ApiAdminService();
  List<CategoryProductAdmin> categories = [];
  final controllerAdd = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _update();
  }

  Future<void> _update() async {
    setState(() {
      isLoading = true;
    });
    try {
      final fetchedCategories = await apiService.getCategories();
      setState(() {
        categories = fetchedCategories;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar("error_loading_data".tr() + e.toString());
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('add_new_category'.tr()),
        content: TextField(
          controller: controllerAdd,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'category_name_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              if (controllerAdd.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controllerAdd.text.trim());
              }
            },
            child: Text('add'.tr()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        isLoading = true;
      });

      // try {
      //   final newCategory =
      //       CategoryProductAdmin(id: 4, name: "name", printerId: 4);

      //   final createdCategory = await apiService.createCategory(newCategory);

      //   if (createdCategory.id != 0) {
      //     controllerAdd.clear();
      //     await _update();
      //     _showSuccessSnackBar('category_added_success'.tr());
      //   } else {
      //     _showErrorSnackBar('category_add_error'.tr());
      //   }
      // } catch (e) {
      //   setState(() {
      //     isLoading = false;
      //   });
      //   _showErrorSnackBar('category_add_error_with_message'
      //       .tr(namedArgs: {'error': e.toString()}));
      // }
    }
  }

  Future<void> _editCategory(int index) async {
    final controller = TextEditingController(text: categories[index].name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('edit_category_name'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'enter_new_name'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );

    if (result != null &&
        result.isNotEmpty &&
        result != categories[index].name) {
      setState(() {
        isLoading = true;
      });

      try {
        final updatedCategory = CategoryProductAdmin(
          id: categories[index].id,
          name: result,
          imageUrl: categories[index].imageUrl,
          printerId: categories[index].printerId,
        );

        final updated = await apiService.updateCategory(updatedCategory);

        if (updated.id != 0) {
          await _update();
          _showSuccessSnackBar('category_updated_success'.tr());
        } else {
          setState(() {
            isLoading = false;
          });
          _showErrorSnackBar('category_update_error'.tr());
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('category_update_error_with_message'
            .tr(namedArgs: {'error': e.toString()}));
      }
    }
  }

  Future<void> _deleteCategory(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_category'.tr()),
        content: Text(
          'delete_category_confirmation'
              .tr(namedArgs: {'categoryName': categories[index].name}),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isLoading = true;
      });

      try {
        final deletedCategory =
            await apiService.deleteCategory(categories[index]);

        if (deletedCategory.id == categories[index].id ||
            deletedCategory.id == 0) {
          await _update();
          _showSuccessSnackBar('category_deleted_success'.tr());
        } else {
          setState(() {
            isLoading = false;
          });
          _showErrorSnackBar('category_delete_error'.tr());
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('category_delete_error_with_message'
            .tr(namedArgs: {'error': e.toString()}));
      }
    }
  }

  // Kategoriyaga bosganda produktslar sahifasiga o'tish
  void _navigateToProducts(CategoryProductAdmin category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductsPage(
          categoryId: category.id,
          categoryName: category.name,
        ),
      ),
    );
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
  void dispose() {
    controllerAdd.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => const UserManagementScreen(),
              //   ),
              // );
            }),
        title: Text('admin_panel'.tr()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _update,
            tooltip: 'refresh'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'logout'.tr(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'no_categories_found'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add),
                        label: Text('add_first_category'.tr()),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200, // Har bir itemning maksimal eni
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1, // nisbatni o'zingiz belgilaysiz
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) => Card(
                    elevation: 4,
                    child: InkWell(
                      // Kategoriya nomiga bosganda mahsulotlar sahifasiga o'tish
                      onTap: () => _navigateToProducts(categories[index]),
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Delete button
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteCategory(index),
                              tooltip: 'delete'.tr(),
                            ),
                          ),
                          // Edit button
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                              ),
                              onPressed: () => _editCategory(index),
                              tooltip: 'edit'.tr(),
                            ),
                          ),
                          // Category name
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    categories[index].name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ID badge
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${categories[index].id}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                          // Arrow icon
                          const Positioned(
                            left: 4,
                            bottom: 4,
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'add_new_category_tooltip'.tr(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
