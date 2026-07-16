import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/audit_log_model.dart';
import 'package:uz_ai_dev/admin/services/audit_log_service.dart';

// Audit jurnali — «kim, qachon, nimani o'zgartirdi?» degan savolga javob.
// GET /api/audit-log (faqat admin). Yozuvlar eng yangisi birinchi keladi,
// tepadagi chiplar orqali obyekt turi bo'yicha filtr qilinadi (filtr
// serverda — chip tanlanganda qayta so'rov ketadi).
//
// old_value/new_value backend tayyorlagan matn — «eski → yangi» ko'rinishida
// aynan ko'rsatiladi (eski qizil, yangi yashil).

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);
const Color _kOld = Color(0xFFD32F2F); // eski qiymat — qizil
const Color _kNew = Color(0xFF2E7D32); // yangi qiymat — yashil

String _fmtDate(DateTime? dt) =>
    dt == null ? '—' : DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());

// Filtr chipi: label + entity qiymati (null = hammasi).
class _EntityFilter {
  final String label;
  final String? entity;
  const _EntityFilter(this.label, this.entity);
}

const List<_EntityFilter> _kFilters = [
  _EntityFilter('Hammasi', null),
  _EntityFilter('Narx', 'product'),
  _EntityFilter('Sklad', 'stock'),
  _EntityFilter('Buyurtma', 'order'),
  _EntityFilter('Qarz', 'magazin_debt'),
  _EntityFilter('To\'lov', 'payment'),
];

// action → o'zbekcha label. Noma'lum action xom holida ko'rsatiladi.
String _actionLabel(String action) {
  switch (action) {
    case 'narx_ozgartirish':
      return 'Narx o\'zgartirildi';
    case 'sklad_korreksiya':
      return 'Sklad korreksiyasi';
    case 'buyurtma_ochirish':
      return 'Buyurtma o\'chirildi';
    case 'qarz_yozish':
      return 'Qarz yozildi';
    case 'qarz_ochirish':
      return 'Qarz o\'chirildi';
    case 'tolov_yaratish':
      return 'To\'lov yaratildi';
    case 'tolov_ochirish':
      return 'To\'lov o\'chirildi';
    default:
      return action;
  }
}

IconData _actionIcon(String action) {
  switch (action) {
    case 'narx_ozgartirish':
      return Icons.sell;
    case 'sklad_korreksiya':
      return Icons.tune;
    case 'buyurtma_ochirish':
    case 'qarz_ochirish':
    case 'tolov_ochirish':
      return Icons.delete_outline;
    case 'qarz_yozish':
      return Icons.receipt_long;
    case 'tolov_yaratish':
      return Icons.payments;
    default:
      return Icons.history;
  }
}

class AuditLogUi extends StatefulWidget {
  const AuditLogUi({super.key});

  @override
  State<AuditLogUi> createState() => _AuditLogUiState();
}

class _AuditLogUiState extends State<AuditLogUi> {
  final AuditLogService _service = AuditLogService();

  List<AuditLogEntry>? _entries;
  bool _loading = true;
  String? _error;
  String? _entityFilter;

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
      final entries = await _service.fetchAuditLog(entity: _entityFilter);
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  void _setFilter(String? entity) {
    if (_entityFilter == entity) return;
    setState(() {
      _entityFilter = entity;
      _entries = null; // eski ro'yxat yangi filtrga tegishli emas
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        title: const Text(
          'Audit jurnali',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _filterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: _kAccent,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  // Obyekt turi bo'yicha filtr chiplari (tor ekranda gorizontal skroll).
  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (final f in _kFilters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.label),
                selected: _entityFilter == f.entity,
                onSelected: (_) => _setFilter(f.entity),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      _entityFilter == f.entity ? Colors.white : Colors.black54,
                ),
                selectedColor: _kAccent,
                backgroundColor: Colors.white,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: _entityFilter == f.entity
                      ? _kAccent
                      : Colors.grey.shade300,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _entries == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    // Xato — backend hali tayyor bo'lmasa ham ekran yiqilmaydi, qayta
    // urinish tugmasi chiqadi.
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
                backgroundColor: _kAccent,
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
              'Hozircha yozuvlar yo\'q',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: entries.length,
      itemBuilder: (context, index) => _entryCard(entries[index]),
    );
  }

  // Pull-to-refresh xato/bo'sh holatda ham ishlashi uchun skrollanadigan markaz.
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

  // Bitta yozuv kartasi: sana + harakat chipi, kim qilgan, qaysi obyekt,
  // eski → yangi qiymat va (bo'lsa) izoh.
  Widget _entryCard(AuditLogEntry e) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1-qator: sana + harakat chipi.
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fmtDate(e.created),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _actionChip(e.action),
              ],
            ),
            const SizedBox(height: 6),
            // 2-qator: kim (rol bilan).
            Text.rich(
              TextSpan(
                text: e.userName.isEmpty ? '—' : e.userName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                children: [
                  if (e.userRole.isNotEmpty)
                    TextSpan(
                      text: ' · ${e.userRole}',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            // 3-qator: obyekt nomi.
            if (e.entityName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                e.entityName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ],
            // 4-qator: eski → yangi (backend tayyorlagan matn, aynan).
            if (e.oldValue.isNotEmpty || e.newValue.isNotEmpty) ...[
              const SizedBox(height: 6),
              _valueLine(e),
            ],
            // 5-qator: izoh.
            if (e.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                e.comment,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionChip(String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_actionIcon(action), size: 14, color: const Color(0xFF8A6F45)),
          const SizedBox(width: 4),
          Text(
            _actionLabel(action),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A6F45),
            ),
          ),
        ],
      ),
    );
  }

  // «eski → yangi». Faqat bittasi bo'lsa — o'zi yolg'iz ko'rsatiladi.
  Widget _valueLine(AuditLogEntry e) {
    const oldStyle = TextStyle(
      fontSize: 13,
      color: _kOld,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    const newStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _kNew,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    if (e.oldValue.isEmpty) {
      return Text(e.newValue, style: newStyle);
    }
    if (e.newValue.isEmpty) {
      return Text(e.oldValue, style: oldStyle);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: e.oldValue, style: oldStyle),
          TextSpan(
            text: '  →  ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          TextSpan(text: e.newValue, style: newStyle),
        ],
      ),
    );
  }
}
