import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/product_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/ui/widgets/tech_card_section.dart';

// Mahsulot tex kartasini (тех карта) ALOHIDA sahifada tahrirlash.
// «i» ikona orqali ochiladi. Saqlanganda mahsulot update qilinadi (faqat
// tech_card o'zgaradi, qolgan maydonlar o'zgarmaydi).
class TechCardEditorPage extends StatefulWidget {
  final ProductModelAdmin product;

  const TechCardEditorPage({super.key, required this.product});

  @override
  State<TechCardEditorPage> createState() => _TechCardEditorPageState();
}

class _TechCardEditorPageState extends State<TechCardEditorPage> {
  late final TechCardController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TechCardController(widget.product.techCard);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final updated = widget.product.copyWith(techCard: _controller.build());
    final provider = context.read<ProductProviderAdmin>();
    final ok = await provider.updateProduct(updated);

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Тех карта сохранена')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Ошибка сохранения'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Сохранить',
                  onPressed: _save,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TechCardSection(
          controller: _controller,
          onChanged: () => setState(() {}),
        ),
      ),
    );
  }
}
