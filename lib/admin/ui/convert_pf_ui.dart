import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/convert_pf_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/services/convert_pf_service.dart';

// «Полуфабрикатga o'tkazish» — admin vositasi.
// Oqim: sahifa ochilishi bilan dry_run=true chaqiriladi va hisobot
// ko'rsatiladi (yaratiladigan pf guruhlari + o'tkazilmaydiganlar sabab
// bilan). Admin «Tasdiqlash» bossagina dry_run=false yuboriladi, yakuniy
// hisobot chiqadi va mahsulotlar ro'yxati BIR MARTA qayta yuklanadi
// (bu vosita kamdan-kam ishlatiladi — to'liq re-fetch maqbul).
class ConvertPfUi extends StatefulWidget {
  const ConvertPfUi({super.key});

  @override
  State<ConvertPfUi> createState() => _ConvertPfUiState();
}

class _ConvertPfUiState extends State<ConvertPfUi> {
  final ConvertPfService _service = ConvertPfService();

  bool _loading = true;
  String? _error;
  ConvertPfReport? _report;
  // true — ko'rsatilayotgan hisobot YAKUNIY (dry_run=false natijasi).
  bool _converted = false;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _runDry();
  }

  Future<void> _runDry() async {
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
      _converted = false;
    });
    try {
      final report = await _service.convert(dryRun: true);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndConvert() async {
    final report = _report;
    if (report == null || _converting) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: Text(
          '${report.created.length} ta полуфабрикат yaratiladi va tegishli '
          'tex kartalardagi bazalar pf qatoriga almashtiriladi.\n\n'
          'Davom etilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'tkazish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _converting = true);
    try {
      final result = await _service.convert(dryRun: false);
      if (!mounted) return;
      setState(() {
        _report = result;
        _converted = true;
        _converting = false;
      });
      // Konvertatsiya mahsulotlarni o'zgartirdi — ro'yxatni bir marta
      // to'liq yangilaymiz (yagona istisno holat).
      await context
          .read<ProductProviderAdmin>()
          .initializeProducts(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konvertatsiya bajarildi')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _converting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Полуфабрикатga o\'tkazish'),
        actions: [
          if (!_loading && !_converted)
            IconButton(
              tooltip: 'Qayta tekshirish',
              onPressed: _converting ? null : _runDry,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 12),
            Text('Tex kartalar tekshirilmoqda...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _runDry,
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    final report = _report;
    if (report == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Holat banneri: tekshiruv (dry run) yoki yakuniy natija.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _converted ? Colors.green.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  _converted ? Colors.green.shade300 : Colors.blue.shade200,
            ),
          ),
          child: Text(
            _converted
                ? 'Konvertatsiya BAJARILDI. Quyida yakuniy hisobot.'
                : 'Bu hali TEKSHIRUV (hech narsa o\'zgartirilmadi). '
                    'Pastdagi tugma bosilgandagina konvertatsiya bajariladi.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _converted
                  ? Colors.green.shade800
                  : Colors.blue.shade800,
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          _converted
              ? 'Yaratilgan полуфабрикатlar (${report.created.length})'
              : 'Yaratiladigan полуфабрикатlar (${report.created.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (report.created.isEmpty)
          Text(
            'Takrorlangan bir xil baza topilmadi.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          for (final c in report.created) _createdCard(c),

        if (report.skipped.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'O\'tkazilmadi (${report.skipped.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final s in report.skipped)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${s.name} — ${s.reason}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _createdCard(ConvertPfCreated c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    border: Border.all(color: Colors.purple.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ПФ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (c.members.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ishlatilgan tex kartalar (${c.members.length}): '
                '${c.members.join(', ')}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _bottomBar() {
    final report = _report;
    if (_loading || _error != null || report == null) return null;
    if (_converted || report.created.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ElevatedButton.icon(
          onPressed: _converting ? null : _confirmAndConvert,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: _converting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.published_with_changes),
          label: Text(
            _converting
                ? 'O\'tkazilmoqda...'
                : 'Tasdiqlash va o\'tkazish (${report.created.length} ta pf)',
          ),
        ),
      ),
    );
  }
}
