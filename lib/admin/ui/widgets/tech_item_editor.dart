import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';

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
            initialValue: _unit,
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
