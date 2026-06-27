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
// Har bir ingredient qatoriga bosish -> tahrirlash, bosib turish -> o'chirish.
// Pastdagi tugma qidiruv sahifasini ochadi va qaytgan ingredientni qo'shadi.
class CompositionSection extends StatefulWidget {
  final CompositionController controller;
  final List<String> units;

  // Tarkib o'zgarganda (qo'shish/tahrirlash/o'chirish) chaqiriladi.
  // Parent ekran «Состав» matnini yangilashi uchun kerak.
  final VoidCallback? onChanged;

  const CompositionSection({
    super.key,
    required this.controller,
    required this.units,
    this.onChanged,
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
      widget.onChanged?.call();
    }
  }

  // Qatorga bosilganda: miqdor (+/-) va birlikni tahrirlash dialogi.
  Future<void> _editItem(int index) async {
    final item = widget.controller.items[index];
    final updated = await showDialog<CompositionItem>(
      context: context,
      builder: (_) => _EditItemDialog(item: item, units: widget.units),
    );
    if (updated != null) {
      setState(() {
        widget.controller.items[index] = updated;
      });
      widget.onChanged?.call();
    }
  }

  // Qatorni bosib turilganda: o'chirish tasdiq dialogi.
  Future<void> _confirmRemove(int index) async {
    final item = widget.controller.items[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('«${item.name}» ni o\'chirasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        widget.controller.items.removeAt(index);
      });
      widget.onChanged?.call();
    }
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
                onPressed: () => _confirmRemove(index),
              ),
              onTap: () => _editItem(index),
              onLongPress: () => _confirmRemove(index),
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

// Ingredient miqdori (+/-) va birligini tahrirlash dialogi.
class _EditItemDialog extends StatefulWidget {
  final CompositionItem item;
  final List<String> units;

  const _EditItemDialog({required this.item, required this.units});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late TextEditingController _amountController;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: _amountToText(widget.item.amount));
    _unit = widget.units.contains(widget.item.unit)
        ? widget.item.unit
        : (widget.units.isNotEmpty ? widget.units.first : widget.item.unit);
  }

  double get _currentAmount =>
      double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0;

  void _setAmount(double value) {
    if (value < 0) value = 0;
    _amountController.text = _amountToText(value);
  }

  void _submit() {
    final amount = _currentAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректное количество')),
      );
      return;
    }
    Navigator.pop(
      context,
      widget.item.copyWith(amount: amount, unit: _unit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _setAmount(_currentAmount - 1)),
              ),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Количество',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _setAmount(_currentAmount + 1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: widget.units.contains(_unit) ? _unit : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ед. изм.',
              border: OutlineInputBorder(),
            ),
            items: widget.units
                .map((u) => DropdownMenuItem<String>(
                      value: u,
                      child: Text(u),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _unit = value ?? _unit;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
