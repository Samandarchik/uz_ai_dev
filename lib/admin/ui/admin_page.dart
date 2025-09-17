import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/services/api_admin_service.dart';
import 'package:uz_ai_dev/admin/ui/products_page.dart';
import 'package:uz_ai_dev/admin/user_management_screen.dart';
import 'package:uz_ai_dev/main.dart';
import 'package:uz_ai_dev/ui/screens/login_page.dart'; // ProductsPage import qiling

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final apiService = ApiAdminService();
  List<CategoryProduct> categories = [];
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
        title: const Text('Yangi kategoriya qo\'shish'),
        content: TextField(
          controller: controllerAdd,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Kategoriya nomini kiriting',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () {
              if (controllerAdd.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controllerAdd.text.trim());
              }
            },
            child: const Text('Qo\'shish'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        isLoading = true;
      });

      try {
        final newCategory = CategoryProduct(
          id: 0, // Server tomonidan generate qilinadi
          name: result,
        );

        final createdCategory = await apiService.createCategory(newCategory);

        if (createdCategory.id != 0) {
          controllerAdd.clear();
          await _update();
          _showSuccessSnackBar('Kategoriya muvaffaqiyatli qo\'shildi!');
        } else {
          _showErrorSnackBar('Kategoriya qo\'shishda xatolik yuz berdi');
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Kategoriya qo\'shishda xatolik: $e');
      }
    }
  }

  Future<void> _editCategory(int index) async {
    final controller = TextEditingController(text: categories[index].name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategoriya nomini tahrirlash'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Yangi nomni kiriting',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Saqlash'),
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
        final updatedCategory = CategoryProduct(
          id: categories[index].id,
          name: result,
        );

        final updated = await apiService.updateCategory(updatedCategory);

        if (updated.id != 0) {
          await _update();
          _showSuccessSnackBar('Kategoriya muvaffaqiyatli yangilandi!');
        } else {
          setState(() {
            isLoading = false;
          });
          _showErrorSnackBar('Kategoriya yangilashda xatolik yuz berdi');
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Kategoriya yangilashda xatolik: $e');
      }
    }
  }

  Future<void> _deleteCategory(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategoriyani o\'chirish'),
        content: Text(
          'Haqiqatan ham "${categories[index].name}" kategoriyasini o\'chirmoqchimisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
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
        final deletedCategory =
            await apiService.deleteCategory(categories[index]);

        if (deletedCategory.id == categories[index].id ||
            deletedCategory.id == 0) {
          await _update();
          _showSuccessSnackBar('Kategoriya muvaffaqiyatli o\'chirildi!');
        } else {
          setState(() {
            isLoading = false;
          });
          _showErrorSnackBar('Kategoriya o\'chirishda xatolik yuz berdi');
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Kategoriya o\'chirishda xatolik: $e');
      }
    }
  }

  // Kategoriyaga bosganda produktslar sahifasiga o'tish
  void _navigateToProducts(CategoryProduct category) {
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
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SafeArea(
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.only(top: 20),
            children: [
              ListTile(
                title: Text('hello'.tr()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('Chiqish'),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _update,
            tooltip: 'Yangilash',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Chiqish',
          ),
          LanguageDropdown(),
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
                      const Text(
                        'Hech qanday kategoriya topilmadi',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add),
                        label: const Text('Birinchi kategoriya qo\'shing'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.2,
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
                              tooltip: 'O\'chirish',
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
                              tooltip: 'Tahrirlash',
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
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Mahsulotlarni ko\'rish uchun bosing',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
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
        tooltip: 'Yangi kategoriya qo\'shish',
        child: const Icon(Icons.add),
      ),
    );
  }
}
