// bugalter/ui/bugalter_edits_ui.dart — bugalter tahrirlari TARIXI ekrani (BugalterEditsUi):
// GET /api/bugalter/edits — kim, qachon, qaysi buyurtma mahsulotining qaysi maydonini
// (soni/summa) o'zgartirgan. Yozuvlar kunlar bo'yicha guruhlanadi, eng yangisi tepada.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/audit_log_model.dart';
import 'package:uz_ai_dev/bugalter/services/bugalter_service.dart';
import 'package:uz_ai_dev/bugalter/ui/widgets/edit_history.dart';

// Bugalter (va admin) uchun tahrirlar tarixi ekrani. Faqat O'QISH:
// yozuvlar serverda append-only saqlanadi, hech qachon o'chirilmaydi.
class BugalterEditsUi extends StatefulWidget {
  const BugalterEditsUi({super.key});

  @override
  State<BugalterEditsUi> createState() => _BugalterEditsUiState();
}

class _BugalterEditsUiState extends State<BugalterEditsUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  final BugalterService _service = BugalterService();

  List<AuditLogEntry>? _entries;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchEdits(limit: 200);
      if (!mounted) return;
      setState(() {
        _entries = list;
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

  // Yozuvlarni lokal kalendar kuni bo'yicha guruhlaydi (kelgan tartib —
  // eng yangisi birinchi — saqlanadi).
  List<MapEntry<DateTime, List<AuditLogEntry>>> _byDay(
      List<AuditLogEntry> entries) {
    final map = <DateTime, List<AuditLogEntry>>{};
    for (final e in entries) {
      final dt = (e.created ?? DateTime(2000)).toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) MapEntry(k, map[k]!)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Tahrirlar tarixi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: _accentColor,
        onRefresh: _load,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _entries == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null && _entries == null) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }

    final entries = _entries ?? const <AuditLogEntry>[];
    if (entries.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Hozircha tahrir qilinmagan',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    final days = _byDay(entries);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: _accentColor),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd.MM.yyyy').format(day.key),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${day.value.length} ta',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const Divider(height: 18),
              for (var i = 0; i < day.value.length; i++) ...[
                if (i > 0) Divider(height: 12, color: Colors.grey.shade200),
                EditHistoryTile(entry: day.value[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  // Pull-to-refresh xato/bo'sh holatda ham ishlashi uchun.
  Widget _scrollableCenter({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
