// admin/ui/sh5_handover_ui.dart — SH5 smena topshirish/qabul ekrani
// (Sh5HandoverCountUi): bitta ekran ikki rejimda ishlaydi —
//   • topshirish (mode = submit): tayanch son = StoreHouse qoldig'i;
//   • qabul     (mode = accept): tayanch son = oldingi kassir topshirgan son.
// Kassir FAQAT farq qilgan qatorni bosib tuzatadi (224 ta tovarni qayta
// terish shart emas) — o'zgartirilmagan qatorlar serverda tayanch son bilan
// yoziladi. Farq chiqsa qizil ko'rinadi va tasdiqlash oynasida sanab beriladi.
//
// SON QOIDASI: ekranda kg/dona ko'rinadi, serverga milli BUTUN son ketadi
// (×1000, sh5MilliFromInput). Float yuborilmaydi.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart' show formatPortions;
import 'package:uz_ai_dev/admin/model/sh5_handover_model.dart';
import 'package:uz_ai_dev/admin/services/sh5_service.dart';
import 'package:uz_ai_dev/admin/ui/widgets/rk7_common.dart';

/// Ekran rejimi.
enum Sh5CountMode { submit, accept }

/// Kiritilgan matndan milli BUTUN son (1.5 → 1500). Vergul ham qabul
/// qilinadi; noto'g'ri matn — null. Yaxlitlash YOZISH chegarasida.
int? sh5MilliFromInput(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v < 0) return null;
  return (v * 1000).round();
}

// Ro'yxatning bitta qatori uchun yagona ko'rinish (rejimdan qat'i nazar).
class _Row {
  final int rid;
  final String name;
  final String unit;
  // baseMilli — tayanch son (StoreHouse yoki topshirilgan).
  final int baseMilli;
  // prevMilli — oldingi smena topshirgan son (0 = ma'lumot yo'q).
  final int prevMilli;

  const _Row({
    required this.rid,
    required this.name,
    required this.unit,
    required this.baseMilli,
    required this.prevMilli,
  });
}

class Sh5HandoverCountUi extends StatefulWidget {
  final Sh5CountMode mode;
  final int skladId;
  final String skladName;
  // Topshirish rejimi uchun — qoralama; qabul uchun null.
  final Sh5HandoverDraft? draft;
  // Qabul rejimi uchun — ochiq topshiriq; topshirish uchun null.
  final Sh5Handover? open;

  const Sh5HandoverCountUi.submit({
    super.key,
    required this.skladId,
    required this.skladName,
    required Sh5HandoverDraft this.draft,
  })  : mode = Sh5CountMode.submit,
        open = null;

  const Sh5HandoverCountUi.accept({
    super.key,
    required this.skladId,
    required this.skladName,
    required Sh5Handover this.open,
  })  : mode = Sh5CountMode.accept,
        draft = null;

  @override
  State<Sh5HandoverCountUi> createState() => _Sh5HandoverCountUiState();
}

class _Sh5HandoverCountUiState extends State<Sh5HandoverCountUi> {
  final Sh5Service _service = Sh5Service();
  final TextEditingController _search = TextEditingController();

  late final List<_Row> _rows;
  // Kassir tuzatgan qatorlar: rid → milli. Faqat shular serverga ketadi.
  final Map<int, int> _edited = {};
  bool _saving = false;
  String _query = '';

  bool get _isSubmit => widget.mode == Sh5CountMode.submit;

  @override
  void initState() {
    super.initState();
    _rows = _isSubmit
        ? widget.draft!.items
            .map((e) => _Row(
                  rid: e.rid,
                  name: e.name,
                  unit: e.unit,
                  baseMilli: e.sh5Milli,
                  prevMilli: e.prevOutMilli,
                ))
            .toList()
        : widget.open!.items
            .map((e) => _Row(
                  rid: e.rid,
                  name: e.name,
                  unit: e.unit,
                  baseMilli: e.outMilli,
                  prevMilli: e.prevOutMilli,
                ))
            .toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Row> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  // Farq chiqqan qatorlar (tasdiqlash oynasi va pastki panel uchun).
  List<_Row> get _diffRows =>
      _rows.where((r) => _edited[r.rid] != null && _edited[r.rid] != r.baseMilli).toList();

  int _factOf(_Row r) => _edited[r.rid] ?? r.baseMilli;

  // ─────────────────────── Miqdor kiritish ───────────────────────

  Future<void> _editRow(_Row r) async {
    final ctrl = TextEditingController(text: formatPortions(_factOf(r)));
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(r.name, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_isSubmit ? 'StoreHouse' : 'Topshirilgan'}: '
              '${formatPortions(r.baseMilli)} ${r.unit}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (r.prevMilli > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Oldingi smena: ${formatPortions(r.prevMilli)} ${r.unit}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Sanaldi (${r.unit.isEmpty ? 'dona' : r.unit})',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onSubmitted: (v) {
                final milli = sh5MilliFromInput(v);
                if (milli != null) Navigator.pop(ctx, milli);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRk7AccentDark),
            onPressed: () {
              final milli = sh5MilliFromInput(ctrl.text);
              if (milli == null) {
                rk7Snack(ctx, 'Son noto\'g\'ri kiritildi', error: true);
                return;
              }
              Navigator.pop(ctx, milli);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (result == r.baseMilli) {
        _edited.remove(r.rid);
      } else {
        _edited[r.rid] = result;
      }
    });
  }

  // ─────────────────────── Saqlash ───────────────────────

  Future<void> _confirmAndSave() async {
    final diffs = _diffRows;
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isSubmit ? 'Smenani topshirish' : 'Smenani qabul qilish'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diffs.isEmpty)
                  const Text(
                    'Farq yo\'q — hamma son to\'g\'ri.',
                    style: TextStyle(fontSize: 14),
                  )
                else ...[
                  Text(
                    '${diffs.length} ta pozitsiyada farq bor:',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...diffs.take(30).map((r) {
                    final fact = _factOf(r);
                    final diff = fact - r.baseMilli;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${r.name}: ${formatPortions(r.baseMilli)} → '
                        '${formatPortions(fact)} ${r.unit} '
                        '(${diff > 0 ? '+' : '−'}${formatPortions(diff.abs())})',
                        style: TextStyle(
                          fontSize: 13,
                          color: diff < 0 ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    );
                  }),
                  if (diffs.length > 30)
                    Text('... va yana ${diffs.length - 30} ta',
                        style: const TextStyle(fontSize: 12)),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Izoh (ixtiyoriy)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRk7AccentDark),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isSubmit ? 'Topshirish' : 'Qabul qilish'),
          ),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      // Serverga FAQAT farq qilgan qatorlar ketadi — qolganini server
      // tayanch son bilan yozadi (kontrakt: sh5_handover.go).
      final payload = {for (final r in diffs) r.rid: _factOf(r)};
      final Sh5Handover? saved = _isSubmit
          ? await _service.submitHandover(
              skladId: widget.skladId, qtyByRid: payload, note: note)
          : await _service.acceptHandover(
              handoverId: widget.open!.id, qtyByRid: payload, note: note);
      if (!mounted) return;
      Navigator.pop(context, saved ?? true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      rk7Snack(context, e.toString().replaceFirst('Exception: ', ''),
          error: true);
    }
  }

  // ─────────────────────── Ko'rinish ───────────────────────

  @override
  Widget build(BuildContext context) {
    final diffCount = _diffRows.length;
    return Scaffold(
      backgroundColor: kRk7Bg,
      appBar: AppBar(
        backgroundColor: kRk7Accent,
        foregroundColor: Colors.white,
        title: Text(_isSubmit ? 'Smenani topshirish' : 'Smenani qabul qilish'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _subtitle(),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Tovar qidirish...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _list()),
          _bottomBar(diffCount),
        ],
      ),
    );
  }

  String _subtitle() {
    if (_isSubmit) {
      final t = widget.draft?.takenAt;
      final when =
          t == null ? '—' : DateFormat('dd.MM HH:mm').format(t.toLocal());
      return '${widget.skladName} • StoreHouse: $when';
    }
    final h = widget.open!;
    final when =
        h.outAt == null ? '' : DateFormat('dd.MM HH:mm').format(h.outAt!.toLocal());
    return '${widget.skladName} • Topshirdi: ${h.outUserName} $when';
  }

  Widget _list() {
    final rows = _visible;
    if (rows.isEmpty) {
      return rk7EmptyState(Icons.search_off, 'Hech narsa topilmadi');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        final fact = _factOf(r);
        final diff = fact - r.baseMilli;
        final changed = diff != 0;
        return ListTile(
          dense: true,
          tileColor: changed
              ? (diff < 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9))
              : Colors.white,
          onTap: _saving ? null : () => _editRow(r),
          title: Text(r.name, style: const TextStyle(fontSize: 14)),
          subtitle: Text(
            '${_isSubmit ? 'StoreHouse' : 'Topshirilgan'}: '
            '${formatPortions(r.baseMilli)} ${r.unit}'
            '${r.prevMilli > 0 ? '  •  oldingi: ${formatPortions(r.prevMilli)}' : ''}',
            style: const TextStyle(fontSize: 11.5),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatPortions(fact)} ${r.unit}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: changed
                      ? (diff < 0 ? Colors.red.shade700 : Colors.green.shade700)
                      : kRk7AccentDark,
                ),
              ),
              if (changed)
                Text(
                  '${diff > 0 ? '+' : '−'}${formatPortions(diff.abs())}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: diff < 0 ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar(int diffCount) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                diffCount == 0
                    ? '${_rows.length} ta tovar • farq yo\'q'
                    : '$diffCount ta pozitsiyada farq',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: diffCount == 0 ? Colors.black54 : Colors.red.shade700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kRk7AccentDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _confirmAndSave,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isSubmit ? 'Topshirish' : 'Qabul qilish'),
            ),
          ],
        ),
      ),
    );
  }
}
