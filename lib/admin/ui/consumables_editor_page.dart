import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_item_editor.dart';

// Расходник (qadoqlash materiallari) ro'yxatini alohida sahifada tahrirlash.
// Chiqishda (✓ yoki back) tahrirlangan List<TechItem> qaytadi.
class ConsumablesEditorPage extends StatefulWidget {
  final List<TechItem> consumables;
  final int batchQty;

  const ConsumablesEditorPage({
    super.key,
    required this.consumables,
    required this.batchQty,
  });

  @override
  State<ConsumablesEditorPage> createState() => _ConsumablesEditorPageState();
}

class _ConsumablesEditorPageState extends State<ConsumablesEditorPage> {
  late List<TechItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<TechItem>.from(widget.consumables);
  }

  List<TechItem> _result() => List<TechItem>.from(_items);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _result());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Расходник'),
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
            const Text(
              'Расходники',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TechItemListEditor(
              items: _items,
              batchQty: widget.batchQty,
              addLabel: 'Расходник',
              onChanged: (list) => setState(() => _items = list),
            ),
          ],
        ),
      ),
    );
  }
}
