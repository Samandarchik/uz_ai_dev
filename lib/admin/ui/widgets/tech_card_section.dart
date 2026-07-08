import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uz_ai_dev/admin/model/tech_card.dart';
import 'package:uz_ai_dev/admin/ui/base_editor_page.dart';
import 'package:uz_ai_dev/admin/ui/consumables_editor_page.dart';

// Tex karta (тех карта) holatini boshqaradigan controller.
// Parent ekran shuni yaratadi, save paytida build() chaqiradi va dispose qiladi.
class TechCardController {
  int batchQty;
  int? diameterCm;
  // Bo'limlar (bosqichlar) — tex karta muharriridagi «Bo'limlar» qatori.
  final List<TechStage> stages;
  final List<TechBase> bases;
  final List<TechItem> consumables;

  TechCardController([TechCard? initial])
      : batchQty = (initial?.batchQty ?? 1) < 1 ? 1 : (initial?.batchQty ?? 1),
        diameterCm = initial?.diameterCm,
        stages = List<TechStage>.from(initial?.stages ?? const []),
        bases = List<TechBase>.from(initial?.bases ?? const []),
        consumables = List<TechItem>.from(initial?.consumables ?? const []);

  // To'liq TechCard ni yig'ib qaytaradi (weight maydonlari mahalliy hisoblanadi).
  TechCard build() => TechCard(
        batchQty: batchQty < 1 ? 1 : batchQty,
        diameterCm: diameterCm,
        stages: List<TechStage>.from(stages),
        bases: List<TechBase>.from(bases),
        consumables: List<TechItem>.from(consumables),
      );

  // «Состав» uchun showInSostav=true bo'lgan nomlar.
  List<String> sostavNames() => build().sostavNames();

  void dispose() {}
}

// Ixcham tex karta muharriri: партия + диаметр, bazalar ro'yxati va
// расходник tugmasi. Bazalar/расходник tahriri alohida sahifalarda.
class TechCardSection extends StatefulWidget {
  final TechCardController controller;

  // Tarkib o'zgarganda (qo'shish/tahrirlash/o'chirish) chaqiriladi.
  final VoidCallback? onChanged;

  const TechCardSection({
    super.key,
    required this.controller,
    this.onChanged,
  });

  @override
  State<TechCardSection> createState() => _TechCardSectionState();
}

class _TechCardSectionState extends State<TechCardSection> {
  late final TextEditingController _batchQtyController;
  late final TextEditingController _diameterController;

  TechCardController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _batchQtyController = TextEditingController(text: c.batchQty.toString());
    _diameterController =
        TextEditingController(text: c.diameterCm?.toString() ?? '');
  }

  @override
  void dispose() {
    _batchQtyController.dispose();
    _diameterController.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged?.call();

  // --- Baza qo'shish ---
  Future<void> _addBase() async {
    final name = await _askBaseName();
    if (name == null) return;
    if (!mounted) return;
    setState(() {
      c.bases.add(TechBase(name: name, ingredients: const []));
    });
    _notify();
  }

  Future<String?> _askBaseName({String initial = ''}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _BaseNameDialog(initial: initial),
    );
    if (name == null || name.isEmpty) return null;
    return name;
  }

  // --- Bazani tahrirlash (alohida sahifa) ---
  Future<void> _openBase(int index) async {
    final result = await Navigator.push<TechBase>(
      context,
      MaterialPageRoute(
        builder: (_) => BaseEditorPage(
          base: c.bases[index],
          batchQty: c.batchQty,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      c.bases[index] = result;
    });
    _notify();
  }

  Future<void> _removeBase(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('«${c.bases[index].name}» ni o\'chirasizmi?'),
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
    if (ok != true) return;
    if (!mounted) return;
    setState(() {
      c.bases.removeAt(index);
    });
    _notify();
  }

  // --- Расходник (alohida sahifa) ---
  Future<void> _openConsumables() async {
    final result = await Navigator.push<List<TechItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => ConsumablesEditorPage(
          consumables: c.consumables,
          batchQty: c.batchQty,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      c.consumables
        ..clear()
        ..addAll(result);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final card = c.build();
    final batchWeight = card.computedBatchWeightG;
    final pieceWeight = card.computedPieceWeightG;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тех карта (состав)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // 1. Партия (nechtaga) + hisoblangan og'irliklar
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: TextField(
                controller: _batchQtyController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nechtaga (партия)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() {
                    c.batchQty = int.tryParse(v.trim()) ?? 1;
                  });
                  _notify();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1 дона ≈ $pieceWeight г',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Партия: $batchWeight г',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Диаметр (ixtiyoriy)
        SizedBox(
          width: 180,
          child: TextField(
            controller: _diameterController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Диаметр (см) — ixtiyoriy',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              c.diameterCm = v.trim().isEmpty ? null : int.tryParse(v.trim());
              _notify();
            },
          ),
        ),
        const SizedBox(height: 16),

        // 3. Базы
        const Text(
          'Базы',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (c.bases.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Базы не добавлены',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ...List.generate(c.bases.length, (i) {
          final base = c.bases[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                base.name.isEmpty ? '(без названия)' : base.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${base.ingredients.length} ингредиент  •  ~${base.computedWeightG} г',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openBase(i),
              onLongPress: () => _removeBase(i),
            ),
          );
        }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addBase,
          icon: const Icon(Icons.add),
          label: const Text('База'),
        ),

        const SizedBox(height: 20),

        // 4. Расходник
        const Text(
          'Расходник',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: const Text('Расходник'),
            subtitle: Text('${c.consumables.length} расходник'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openConsumables,
          ),
        ),
      ],
    );
  }
}

// Baza nomini so'rovchi dialog. O'z controllerini o'zi yaratadi va dispose qiladi,
// shunda dialog yopilish animatsiyasi paytida disposed controllerга murojaat bo'lmaydi.
class _BaseNameDialog extends StatefulWidget {
  final String initial;

  const _BaseNameDialog({this.initial = ''});

  @override
  State<_BaseNameDialog> createState() => _BaseNameDialogState();
}

class _BaseNameDialogState extends State<_BaseNameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая база'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Название базы',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
