// admin/ui/widgets/tech_item_editor.dart — тех карта editori sub-vidjeti:
// confirmDeleteTechItem (ingredient o'chirishni tasdiqlash dialogi).
// (Miqdor/birlik tahriri endi qator ichida — tech_card_editor_page.dart
// _InlineAmountCell + birlik menyusi; eski EditTechItemDialog olib tashlangan.)
import 'package:flutter/material.dart';

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
