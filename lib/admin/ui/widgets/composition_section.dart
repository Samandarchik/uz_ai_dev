import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/composition_item.dart';
import 'package:uz_ai_dev/admin/ui/composition_picker_page.dart';

// Composition (tarkib) holatini boshqaradigan controller.
// Endi ingredientlar qo'lda yozilmaydi — qidiruv sahifasidan tanlanadi.
// Parent ekran shuni yaratadi, save paytida build() chaqiradi va dispose qiladi.
class CompositionController {
  final List<CompositionItem> items;

  CompositionController([List<CompositionItem>? initial])
      : items = List<CompositionItem>.from(initial ?? const []);

  // To'liq ro'yxatni qaytaradi.
  List<CompositionItem> build() => List<CompositionItem>.from(items);

  void dispose() {
    // Controller ichida tashlanadigan resurs yo'q (text controllerlar olib tashlandi).
  }
}

// Miqdorni chiroyli matnga aylantiradi (1.0 -> "1").
String _amountToText(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toInt().toString();
  }
  return amount.toString();
}

// "Ингредиенты / Tarkib" bo'limi UI.
// Har bir ingredient read-only ko'rinadi (nom + miqdor + birlik), faqat o'chirish mumkin.
// Pastdagi tugma qidiruv sahifasini ochadi va qaytgan ingredientni qo'shadi.
class CompositionSection extends StatefulWidget {
  final CompositionController controller;
  final List<String> units;

  const CompositionSection({
    super.key,
    required this.controller,
    required this.units,
  });

  @override
  State<CompositionSection> createState() => _CompositionSectionState();
}

class _CompositionSectionState extends State<CompositionSection> {
  Future<void> _addIngredient() async {
    final result = await Navigator.push<CompositionItem>(
      context,
      MaterialPageRoute(
        builder: (_) => CompositionPickerPage(units: widget.units),
      ),
    );
    if (result != null) {
      setState(() {
        widget.controller.items.add(result);
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      widget.controller.items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ингредиенты (состав)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Ингредиенты не добавлены',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text(item.name),
              subtitle: Text('${_amountToText(item.amount)} ${item.unit}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addIngredient,
          icon: const Icon(Icons.add),
          label: const Text('Добавить ингредиент'),
        ),
      ],
    );
  }
}
