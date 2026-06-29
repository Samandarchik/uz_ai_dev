import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_item_editor.dart';

// Bitta bazani (TechBase) alohida sahifada tahrirlash.
// Chiqishda (✓ yoki back) tahrirlangan TechBase qaytadi.
class BaseEditorPage extends StatefulWidget {
  final TechBase base;
  final int batchQty;

  const BaseEditorPage({
    super.key,
    required this.base,
    required this.batchQty,
  });

  @override
  State<BaseEditorPage> createState() => _BaseEditorPageState();
}

class _BaseEditorPageState extends State<BaseEditorPage> {
  late final TextEditingController _nameController;
  late List<TechItem> _ingredients;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.base.name);
    _ingredients = List<TechItem>.from(widget.base.ingredients);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Joriy holatdan tahrirlangan bazani yig'ib qaytaradi.
  TechBase _result() => widget.base.copyWith(
        name: _nameController.text.trim(),
        ingredients: List<TechItem>.from(_ingredients),
      );

  @override
  Widget build(BuildContext context) {
    final base = _result();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _result());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('База'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, _result()),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название базы',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              'Вес базы: ~${base.computedWeightG} г',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ингредиенты',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TechItemListEditor(
              items: _ingredients,
              batchQty: widget.batchQty,
              addLabel: 'Ингредиент',
              onChanged: (list) => setState(() => _ingredients = list),
            ),
          ],
        ),
      ),
    );
  }
}
