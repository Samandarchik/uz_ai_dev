// admin/ui/sh5_handover_ui.dart — SH5 smena topshirish/qabul ekrani
// (Sh5HandoverCountUi): bitta ekran ikki rejimda ishlaydi —
//   • topshirish (mode = submit): tayanch son = StoreHouse qoldig'i;
//   • qabul     (mode = accept): tayanch son = oldingi kassir topshirgan son.
// Son maydoni qatorning O'ZIDA tahrirlanadi (dialog YO'Q): bosish bilan
// klaviatura ochiladi va matn to'liq tanlanadi — ustiga yozib ketaveradi.
// Kassir FAQAT farq qilgan qatorni tuzatadi (224 ta tovarni qayta terish
// shart emas) — o'zgartirilmagan qatorlar serverda tayanch son bilan
// yoziladi. Farq chiqsa qator qizil/yashil bo'ladi va tasdiqlashdan oldin
// sanab beriladi.
//
// SON QOIDASI: ekranda kg/dona ko'rinadi, serverga milli BUTUN son ketadi
// (×1000, sh5MilliFromInput). Float yuborilmaydi.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Har qatorning kiritish maydoni — rid bo'yicha kesh. ListView.builder
  // faqat ko'rinadigan qatorni quradi, shuning uchun controller ham FAQAT
  // ko'rilgan qatorlar uchun yaratiladi (224 ta tovarda ham yengil).
  final Map<int, TextEditingController> _ctrls = {};
  final Map<int, FocusNode> _nodes = {};
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
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    _search.dispose();
    super.dispose();
  }

  // Qator maydonining controlleri (birinchi ko'rinishda yaratiladi).
  TextEditingController _ctrlFor(_Row r) => _ctrls.putIfAbsent(
      r.rid, () => TextEditingController(text: formatPortions(_factOf(r))));

  // Fokus KELGANDA butun matn tanlanadi (ustiga darhol yozib ketiladi),
  // KETGANDA bo'sh/noto'g'ri matn tayanch songa qaytariladi — maydon hech
  // qachon «bo'sh» holatda qolib ketmasin.
  FocusNode _nodeFor(_Row r) => _nodes.putIfAbsent(r.rid, () {
        final node = FocusNode();
        node.addListener(() {
          final ctrl = _ctrls[r.rid];
          if (ctrl == null) return;
          if (node.hasFocus) {
            ctrl.selection =
                TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
            return;
          }
          if (sh5MilliFromInput(ctrl.text) == null) {
            ctrl.text = formatPortions(_factOf(r));
          }
        });
        return node;
      });

  // Matn o'zgarganda: to'g'ri son bo'lsa yozamiz, tayanch songa teng bo'lsa
  // «tuzatilmagan» deb hisoblanadi (serverga yuborilmaydi).
  void _onQtyChanged(_Row r, String text) {
    final milli = sh5MilliFromInput(text);
    setState(() {
      if (milli == null || milli == r.baseMilli) {
        _edited.remove(r.rid);
      } else {
        _edited[r.rid] = milli;
      }
    });
  }

  List<_Row> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  // Farq chiqqan qatorlar (tasdiqlash oynasi va pastki panel uchun).
  List<_Row> get _diffRows => _rows
      .where((r) => _edited[r.rid] != null && _edited[r.rid] != r.baseMilli)
      .toList();

  int _factOf(_Row r) => _edited[r.rid] ?? r.baseMilli;

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
                          color: diff < 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
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
    final when = h.outAt == null
        ? ''
        : DateFormat('dd.MM HH:mm').format(h.outAt!.toLocal());
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
      itemBuilder: (context, i) => _row(rows[i]),
    );
  }

  // Bitta qator: chapda nom + tayanch son, o'ngda TO'G'RIDAN-TO'G'RI
  // tahrirlanadigan son maydoni (dialog yo'q — bosish bilan klaviatura
  // ochiladi va matn tanlanadi).
  Widget _row(_Row r) {
    final fact = _factOf(r);
    final diff = fact - r.baseMilli;
    final changed = diff != 0;
    final color = diff < 0 ? Colors.red.shade700 : Colors.green.shade700;
    final node = _nodeFor(r);
    // BUTUN qator bosiladi — nomi, bo'sh joyi, sonining atrofi ham. Maydonning
    // o'zi bosilsa TextField'ning ichki ishlovchisi ustun keladi (bola vidjet
    // gesture arenasida yutadi), shuning uchun ikkalasi ham to'g'ri ishlaydi.
    return GestureDetector(
      onTap: _saving ? null : () => _focusRow(r),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: changed
            ? (diff < 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9))
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.name, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${_isSubmit ? 'StoreHouse' : 'Topshirilgan'}: '
                    '${formatPortions(r.baseMilli)} ${r.unit}'
                    '${r.prevMilli > 0 ? '  •  oldingi: ${formatPortions(r.prevMilli)}' : ''}',
                    style:
                        const TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: TextField(
                controller: _ctrlFor(r),
                focusNode: node,
                enabled: !_saving,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: changed ? color : kRk7AccentDark,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  suffixText: r.unit.isEmpty ? null : r.unit,
                  suffixStyle:
                      const TextStyle(fontSize: 11, color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: changed ? color : Colors.grey.shade300,
                        width: changed ? 1.4 : 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: kRk7AccentDark, width: 1.6),
                  ),
                ),
                // Matnni tanlash fokus listenerida (ikkinchi bosishda kursor
                // joylashtirish ishlashi uchun bu yerda tanlanmaydi).
                // scrollPadding — klaviatura ochilganda qator uning ostida
                // qolib ketmasin.
                scrollPadding: const EdgeInsets.only(bottom: 120),
                onChanged: (v) => _onQtyChanged(r, v),
                onSubmitted: (_) => node.unfocus(),
              ),
            ),
            SizedBox(
              width: 52,
              child: changed
                  ? Text(
                      '${diff > 0 ? '+' : '−'}${formatPortions(diff.abs())}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // Qatorning istalgan joyi bosilganda maydonni ochish. DIQQAT:
  // requestFocus() o'zi telefonda klaviaturani HAR DOIM ochmaydi (maydonning
  // o'z bosish ishlovchisi orqali kelmagani uchun) — shuning uchun
  // TextInput.show ham chaqiriladi. Desktopda bu buyruq zararsiz.
  void _focusRow(_Row r) {
    final node = _nodeFor(r);
    if (node.hasFocus) {
      // Allaqachon ochiq — matnni qayta tanlaymiz (ustiga yozish uchun).
      _ctrlFor(r).selection =
          TextSelection(baseOffset: 0, extentOffset: _ctrlFor(r).text.length);
      return;
    }
    node.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  Widget _bottomBar(int diffCount) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 6),
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
