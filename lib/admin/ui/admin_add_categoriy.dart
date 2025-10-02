import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/category_model.dart';
import 'package:uz_ai_dev/admin/ui/dealog.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/admin/services/upload_image.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProviderAdminUpload>().getCategories();
    });
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => const CategoryDialog(),
    );
  }

  void _showUpdateDialog(CategoryProductAdmin category) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(category: category),
    );
  }

  void _deleteCategory(CategoryProductAdmin category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<CategoryProviderAdminUpload>();
      final success = await provider.deleteCategory(category);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Category deleted' : 'Failed to delete'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: Consumer<CategoryProviderAdminUpload>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.categories.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.error != null && provider.categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${provider.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => provider.getCategories(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add one',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.getCategories(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.categories.length,
              itemBuilder: (context, index) {
                final category = provider.categories[index];
                return CategoryListTile(
                  category: category,
                  onEdit: () => _showUpdateDialog(category),
                  onDelete: () => _deleteCategory(category),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class CategoryListTile extends StatelessWidget {
  final CategoryProductAdmin category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CategoryListTile({
    Key? key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: category.imageUrl != null
            ? Image.network(
                "${AppUrls.baseUrl}${category.imageUrl!}",
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 32),
                  );
                },
              )
            : Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.category, size: 32),
              ),
      ),
      title: Text(
        category.name,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Printer: ${category.printerId}',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: Colors.black),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
