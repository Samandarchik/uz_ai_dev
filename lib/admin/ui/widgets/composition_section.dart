import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/composition_item.dart';

// Bitta ingredient qatori uchun controllerlar.
class CompositionRow {
  final TextEditingController nameController;
  final TextEditingController amountController;
  String unit;

  CompositionRow({String name = '', String amount = '', this.unit = ''})
      : nameController = TextEditingController(text: name),
        amountController = TextEditingController(text: amount);

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

// Composition (tarkib) holatini boshqaradigan controller.
// Parent ekran shuni yaratadi, save paytida build() chaqiradi va dispose qiladi.
class CompositionController {
  final List<CompositionRow> rows;

  CompositionController([List<CompositionItem>? initial])
      : rows = (initial ?? [])
            .map((e) => CompositionRow(
                  name: e.name,
                  amount: _amountToText(e.amount),
                  unit: e.unit,
                ))
            .toList();

  static String _amountToText(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toString();
  }

  // Bo'sh nomli qatorlarni tashlab, to'liq ro'yxatni qaytaradi.
  List<CompositionItem> build() {
    return rows
        .where((r) => r.nameController.text.trim().isNotEmpty)
        .map((r) => CompositionItem(
              name: r.nameController.text.trim(),
              amount: double.tryParse(
                      r.amountController.text.trim().replaceAll(',', '.')) ??
                  0,
              unit: r.unit,
            ))
        .toList();
  }

  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
  }
}

// "Ингредиенты / Tarkib" bo'limi UI.
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
  void _addRow() {
    setState(() {
      widget.controller.rows.add(CompositionRow(
        unit: widget.units.isNotEmpty ? widget.units.first : '',
      ));
    });
  }

  void _removeRow(int index) {
    setState(() {
      widget.controller.rows[index].dispose();
      widget.controller.rows.removeAt(index);
    });
  }

  String _effectiveUnit(CompositionRow row) {
    if (widget.units.contains(row.unit)) return row.unit;
    return widget.units.isNotEmpty ? widget.units.first : '';
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.controller.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ингредиенты (состав)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(rows.length, (index) {
          final row = rows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nomi
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: row.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Miqdori
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.amountController,
                    decoration: const InputDecoration(
                      labelText: 'Кол-во',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Birligi (dropdown)
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value:
                        widget.units.isEmpty ? null : _effectiveUnit(row),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ед.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: widget.units
                        .map((u) => DropdownMenuItem<String>(
                              value: u,
                              child: Text(u),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        row.unit = value ?? row.unit;
                      });
                    },
                  ),
                ),
                // O'chirish
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeRow(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add),
          label: const Text('Добавить ингредиент'),
        ),
      ],
    );
  }
}
