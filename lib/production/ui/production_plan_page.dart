// production/ui/production_plan_page.dart — kunlik ishlab chiqarish rejasi
// (MRP) ekrani: ProductionPlanPage — tanlangan kun buyurtmalaridan tortlar,
// П/Ф ehtiyoji (qoldiq/band netting bilan) va xomashyo defitsiti.
// Admin menyudan va shef bosh ekranidan ochiladi.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/production/models/production_plan_model.dart';
import 'package:uz_ai_dev/production/services/production_service.dart';

class ProductionPlanPage extends StatefulWidget {
  const ProductionPlanPage({super.key});

  @override
  State<ProductionPlanPage> createState() => _ProductionPlanPageState();
}

class _ProductionPlanPageState extends State<ProductionPlanPage> {
  DateTime _date = DateTime.now();
  Future<ProductionPlan>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  void _load() {
    setState(() {
      _future = ProductionService().fetchRequirements(date: _dateStr);
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      _date = d;
      _load();
    }
  }

  // П/Ф soni: butun bo'lsa butun, aks holda 1 xona kasr bilan.
  String _pcs(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ishlab chiqarish rejasi'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text('${_date.day.toString().padLeft(2, '0')}.'
                '${_date.month.toString().padLeft(2, '0')}.${_date.year}'),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: FutureBuilder<ProductionPlan>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snap.error}'.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center),
            ));
          }
          final plan = snap.data!;
          if (plan.cakes.isEmpty) {
            return const Center(
                child: Text('Bu kunga tex kartali buyurtma yo\'q'));
          }
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (plan.unlinked.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      '⚠️ Katalogga bog\'lanmagan retsept qatorlari '
                      '(hisobga kirmadi): ${plan.unlinked.join(', ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                _sectionTitle('🎂 Buyurtma qilingan tortlar (${plan.cakes.length})'),
                ...plan.cakes.map((c) => ListTile(
                      dense: true,
                      title: Text(c.name),
                      subtitle: Text('${c.orders} ta buyurtmada'),
                      trailing: Text('${_pcs(c.qty)} dona',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    )),
                const Divider(height: 24),
                _sectionTitle('🧩 П/Ф ehtiyoji (${plan.pf.length})'),
                _pfHeader(),
                ...plan.pf.map(_pfRow),
                const Divider(height: 24),
                _sectionTitle('🌾 Xomashyo (${plan.raw.length})'),
                _rawHeader(),
                ...plan.raw.map(_rawRow),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  static const _kHead = TextStyle(fontSize: 11, color: Colors.grey);

  Widget _pfHeader() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(children: [
          Expanded(flex: 5, child: Text('Nomi', style: _kHead)),
          Expanded(flex: 2, child: Text('Kerak', style: _kHead, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('Bor', style: _kHead, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('Ishlab chiqarish', style: _kHead, textAlign: TextAlign.right)),
        ]),
      );

  Widget _pfRow(PlanPf p) {
    final avail = (p.stock - p.reserved).clamp(0, double.infinity).toDouble();
    final need = p.toProduce > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Expanded(flex: 5, child: Text(p.name, style: const TextStyle(fontSize: 13))),
        Expanded(
            flex: 2,
            child: Text(_pcs(p.required), textAlign: TextAlign.right)),
        Expanded(
            flex: 2,
            child: Text(_pcs(avail),
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey.shade700))),
        Expanded(
          flex: 3,
          child: Text(need ? '${_pcs(p.toProduce)} ${p.unit}' : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: need ? FontWeight.bold : FontWeight.normal,
                  color: need ? Colors.red.shade700 : Colors.green)),
        ),
      ]),
    );
  }

  Widget _rawHeader() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(children: [
          Expanded(flex: 5, child: Text('Nomi', style: _kHead)),
          Expanded(flex: 3, child: Text('Kerak', style: _kHead, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('Bor', style: _kHead, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('Yetishmaydi', style: _kHead, textAlign: TextAlign.right)),
        ]),
      );

  Widget _rawRow(PlanRaw r) {
    final short = r.deficit > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Expanded(flex: 5, child: Text(r.name, style: const TextStyle(fontSize: 13))),
        Expanded(
            flex: 3,
            child: Text(formatQtyUnit(r.required, r.type),
                textAlign: TextAlign.right)),
        Expanded(
            flex: 3,
            child: Text(formatQtyUnit(r.stock, r.type),
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey.shade700))),
        Expanded(
          flex: 3,
          child: Text(short ? formatQtyUnit(r.deficit, r.type) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: short ? FontWeight.bold : FontWeight.normal,
                  color: short ? Colors.red.shade700 : Colors.green)),
        ),
      ]),
    );
  }
}
