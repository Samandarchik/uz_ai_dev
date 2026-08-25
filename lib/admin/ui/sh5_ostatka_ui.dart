// admin/ui/sh5_ostatka_ui.dart — «Ostatka» (SH5 qoldiqlari):
// Sh5OstatkaUi — omborlar ro'yxati; Sh5OstatkaDetailUi — bitta ombor tovarlari
// qidiruv bilan («Coca Cola 0.5L — 5 шт») + smena topshirish/qabul qilish,
// bridge'dan yangilash va tarix.
//
// KO'RSATISH RUXSATI backendda: admin hamma omborni, sotuvchi faqat o'ziga
// biriktirilganini oladi (User.Sh5Sklads) — shu sabab ekran rolni O'ZI
// tekshirmaydi, ro'yxat bo'sh kelsa «ombor biriktirilmagan» deydi.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart' show formatPortions;
import 'package:uz_ai_dev/admin/model/sh5_handover_model.dart';
import 'package:uz_ai_dev/admin/model/sh5_remain_model.dart';
import 'package:uz_ai_dev/admin/services/sh5_service.dart';
import 'package:uz_ai_dev/admin/ui/sh5_handover_history_ui.dart';
import 'package:uz_ai_dev/admin/ui/sh5_handover_ui.dart';
import 'package:uz_ai_dev/admin/ui/widgets/rk7_common.dart';
import 'package:uz_ai_dev/core/context_extension.dart';

// ─────────────────────── Omborlar ro'yxati ───────────────────────

class Sh5OstatkaUi extends StatefulWidget {
  const Sh5OstatkaUi({super.key});

  @override
  State<Sh5OstatkaUi> createState() => _Sh5OstatkaUiState();
}

class _Sh5OstatkaUiState extends State<Sh5OstatkaUi> {
  final Sh5Service _service = Sh5Service();
  List<Sh5RemainSklad> _sklads = [];
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
      final sklads = await _service.fetchSklads();
      if (!mounted) return;
      setState(() {
        _sklads = sklads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kRk7Bg,
      appBar: AppBar(
        backgroundColor: kRk7Accent,
        foregroundColor: Colors.white,
        title: const Text('Ostatka (SH5)'),
        actions: [
          IconButton(
            tooltip: 'Topshiriqlar tarixi',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(const Sh5HandoverHistoryUi()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return rk7ErrorState(_error!, onRetry: _load);
    if (_sklads.isEmpty) {
      return rk7EmptyState(
        Icons.inventory_2_outlined,
        'Ombor ko\'rinmadi.\nSizga ombor biriktirilmagan bo\'lishi mumkin —\n'
        'admin «Ostatka omborlari» ruxsatini beradi.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _sklads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = _sklads[i];
        final taken = s.takenAt == null
            ? '—'
            : DateFormat('dd.MM HH:mm').format(s.takenAt!.toLocal());
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.warehouse_outlined, color: kRk7AccentDark),
            title: Text(
              s.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Yangilangan: $taken'),
            trailing: rk7Badge('${s.goodsCount} tovar', color: kRk7AccentDark),
            onTap: () => context.push(Sh5OstatkaDetailUi(sklad: s)),
          ),
        );
      },
    );
  }
}

// ─────────────────────── Bitta ombor tovarlari ───────────────────────

class Sh5OstatkaDetailUi extends StatefulWidget {
  final Sh5RemainSklad sklad;
  const Sh5OstatkaDetailUi({super.key, required this.sklad});

  @override
  State<Sh5OstatkaDetailUi> createState() => _Sh5OstatkaDetailUiState();
}

class _Sh5OstatkaDetailUiState extends State<Sh5OstatkaDetailUi> {
  final Sh5Service _service = Sh5Service();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  Sh5RemainDetail? _detail;
  // Qabul kutayotgan topshiriq (yo'q bo'lsa null) — pastki tugma shunga qarab
  // «Qabul qilish» yoki «Smenani topshirish» bo'ladi.
  Sh5Handover? _open;
  // StoreHouse snapshot vaqti — bridge yangilagach o'zgaradi.
  DateTime? _takenAt;
  bool _loading = true;
  // _busy — bridge yangilash yoki qoralama yuklanmoqda (tugmalar bloklanadi).
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _takenAt = widget.sklad.takenAt;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Tovarlar va ochiq topshiriq — parallel (ikkalasi ham har kirishda kerak).
      final results = await Future.wait([
        _service.fetchDetail(widget.sklad.id, q: _search.text),
        _service.fetchOpen(widget.sklad.id),
      ]);
      if (!mounted) return;
      final detail = results[0] as Sh5RemainDetail?;
      setState(() {
        _detail = detail;
        _open = results[1] as Sh5Handover?;
        _takenAt = detail?.takenAt ?? _takenAt;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  // ─────────────────── Bridge'dan yangilash ───────────────────

  // Bridge (StoreHouse serveridagi xizmat) so'rovni POLL qilib oladi, keyin
  // push qiladi — shuning uchun so'rovdan keyin taken_at o'zgarishini kutamiz.
  Future<void> _refreshFromBridge() async {
    final before = _takenAt;
    setState(() => _busy = true);
    try {
      await _service.requestRefresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      rk7Snack(context, e.toString().replaceFirst('Exception: ', ''),
          error: true);
      return;
    }
    // 2 soniyada bir, 30 soniyagacha.
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final detail = await _service.fetchDetail(widget.sklad.id,
            q: _search.text);
        if (!mounted) return;
        final taken = detail?.takenAt;
        if (taken != null && (before == null || taken.isAfter(before))) {
          setState(() {
            _detail = detail;
            _takenAt = taken;
            _busy = false;
          });
          rk7Snack(context, 'Qoldiq yangilandi');
          return;
        }
      } catch (_) {
        // Tarmoq uzilishi — keyingi urinishda qayta so'raladi.
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    rk7Snack(
      context,
      'Bridge javob bermadi — oxirgi ma\'lumot ko\'rsatilmoqda',
      error: true,
    );
  }

  // ─────────────────── Topshirish / qabul ───────────────────

  Future<void> _startHandover() async {
    setState(() => _busy = true);
    try {
      final draft = await _service.fetchDraft(widget.sklad.id);
      if (!mounted) return;
      setState(() => _busy = false);
      if (draft == null) {
        rk7Snack(context, 'Qoralama olinmadi', error: true);
        return;
      }
      if (draft.hasOpen) {
        // Oradan boshqa kassir topshirib qo'ygan — avval qabul qilinadi.
        rk7Snack(context, 'Avval oldingi smenani qabul qiling');
        await _load();
        return;
      }
      final saved = await Navigator.push<Object?>(
        context,
        MaterialPageRoute(
          builder: (_) => Sh5HandoverCountUi.submit(
            skladId: widget.sklad.id,
            skladName: widget.sklad.name,
            draft: draft,
          ),
        ),
      );
      if (!mounted || saved == null) return;
      rk7Snack(context, 'Smena topshirildi');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      rk7Snack(context, e.toString().replaceFirst('Exception: ', ''),
          error: true);
    }
  }

  Future<void> _acceptHandover() async {
    final open = _open;
    if (open == null) return;
    final saved = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => Sh5HandoverCountUi.accept(
          skladId: widget.sklad.id,
          skladName: widget.sklad.name,
          open: open,
        ),
      ),
    );
    if (!mounted || saved == null) return;
    if (saved is Sh5Handover && saved.shortageCount > 0) {
      rk7Snack(context, '${saved.shortageCount} ta pozitsiyada kamomad!',
          error: true);
    } else {
      rk7Snack(context, 'Smena qabul qilindi');
    }
    await _load();
  }

  // ─────────────────── Ko'rinish ───────────────────

  @override
  Widget build(BuildContext context) {
    final taken = _takenAt == null
        ? null
        : DateFormat('dd.MM HH:mm').format(_takenAt!.toLocal());
    return Scaffold(
      backgroundColor: kRk7Bg,
      appBar: AppBar(
        backgroundColor: kRk7Accent,
        foregroundColor: Colors.white,
        title: Text(widget.sklad.name),
        actions: [
          IconButton(
            tooltip: 'StoreHouse\'dan yangilash',
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            onPressed: _busy ? null : _refreshFromBridge,
          ),
          IconButton(
            tooltip: 'Topshiriqlar tarixi',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(Sh5HandoverHistoryUi(
              skladId: widget.sklad.id,
              title: widget.sklad.name,
            )),
          ),
        ],
        bottom: taken == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Yangilangan: $taken',
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
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tovar nomi bo\'yicha qidirish...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _load();
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
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _body()),
          ),
          _actionBar(),
        ],
      ),
    );
  }

  // Pastki panel: ochiq topshiriq bo'lsa «Qabul qilish», aks holda
  // «Smenani topshirish».
  Widget _actionBar() {
    final open = _open;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 6),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (open != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${open.outUserName} smenani topshirgan — qabul qiling',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      open == null ? kRk7AccentDark : Colors.orange.shade800,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _busy || _loading
                    ? null
                    : (open == null ? _startHandover : _acceptHandover),
                icon: Icon(open == null
                    ? Icons.assignment_turned_in_outlined
                    : Icons.how_to_reg_outlined),
                label: Text(
                    open == null ? 'Smenani topshirish' : 'Smenani qabul qilish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return rk7ErrorState(_error!, onRetry: _load);
    final goods = _detail?.goods ?? const <Sh5RemainGood>[];
    if (goods.isEmpty) {
      return rk7EmptyState(
        Icons.search_off,
        _search.text.trim().isEmpty
            ? 'Bu omborda qoldiq yo\'q'
            : 'Hech narsa topilmadi',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: goods.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final g = goods[i];
        final qty = formatPortions(g.qtyMilli);
        return ListTile(
          dense: true,
          tileColor: Colors.white,
          title: Text(g.name),
          trailing: Text(
            g.unit.isEmpty ? qty : '$qty ${g.unit}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: kRk7AccentDark,
            ),
          ),
        );
      },
    );
  }
}
