import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/admin/ui/composition_picker_page.dart';

// «1 дона» uchun matn (butun yoki bitta o'nlik raqam).
String techPerPiece(int amount, int batchQty) {
  if (batchQty <= 0) return '—';
  final per = amount / batchQty;
  return per == per.roundToDouble()
      ? per.toInt().toString()
      : per.toStringAsFixed(1);
}

// O'chirishni tasdiqlash dialogi.
Future<bool> confirmDeleteTechItem(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удаление'),
      content: Text('«$name» ni o\'chirasizmi?'),
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
  return ok == true;
}

// TechItem ro'yxatini tahrirlovchi qayta ishlatiluvchi widget.
// Ingredientlar (baza ichida) va расходниклар uchun bir xil ishlatiladi.
class TechItemListEditor extends StatelessWidget {
  final List<TechItem> items;
  final int batchQty;
  final String addLabel;
  final ValueChanged<List<TechItem>> onChanged;

  const TechItemListEditor({
    super.key,
    required this.items,
    required this.batchQty,
    required this.addLabel,
    required this.onChanged,
  });

  Future<void> _add(BuildContext context) async {
    final item = await Navigator.push<TechItem>(
      context,
      MaterialPageRoute(builder: (_) => const CompositionPickerPage()),
    );
    if (item == null) return;
    onChanged([...items, item]);
  }

  Future<void> _edit(BuildContext context, int index) async {
    final updated = await showDialog<TechItem>(
      context: context,
      builder: (_) => EditTechItemDialog(item: items[index]),
    );
    if (updated == null) return;
    final list = List<TechItem>.from(items);
    list[index] = updated;
    onChanged(list);
  }

  Future<void> _delete(BuildContext context, int index) async {
    if (!await confirmDeleteTechItem(context, items[index].name)) return;
    final list = List<TechItem>.from(items)..removeAt(index);
    onChanged(list);
  }

  void _toggle(int index, bool value) {
    final list = List<TechItem>.from(items);
    list[index] = list[index].copyWith(showInSostav: value);
    onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Пусто',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ...List.generate(items.length, (i) {
          final item = items[i];
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(item.name),
            subtitle: Text(
              '${item.amount} ${techUnitLabel(item.unit)}'
              '${batchQty > 0 ? '  •  1 дона = ${techPerPiece(item.amount, batchQty)} ${techUnitLabel(item.unit)}' : ''}',
            ),
            trailing: Switch.adaptive(
              value: item.showInSostav,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => _toggle(i, v),
            ),
            onTap: () => _edit(context, i),
            onLongPress: () => _delete(context, i),
          );
        }),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }
}

// Ingredient miqdori (butun son) + birligini (g/ml/pcs/m) tahrirlash dialogi.
class EditTechItemDialog extends StatefulWidget {
  final TechItem item;

  const EditTechItemDialog({super.key, required this.item});

  @override
  State<EditTechItemDialog> createState() => _EditTechItemDialogState();
}

class _EditTechItemDialogState extends State<EditTechItemDialog> {
  late final TextEditingController _amountController;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.item.amount.toString());
    _unit = kTechUnits.contains(widget.item.unit) ? widget.item.unit : 'g';
  }

  int get _currentAmount => int.tryParse(_amountController.text.trim()) ?? 0;

  void _setAmount(int value) {
    if (value < 0) value = 0;
    _amountController.text = value.toString();
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Количество (целое)',
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
            value: _unit,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ед. изм.',
              border: OutlineInputBorder(),
            ),
            items: kTechUnits
                .map((u) => DropdownMenuItem<String>(
                      value: u,
                      child: Text(techUnitLabel(u)),
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
