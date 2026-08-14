// admin/ui/sh5_ostatka_ui.dart — «Ostatka» (SH5 qoldiqlari, faqat admin):
// Sh5OstatkaUi — omborlar ro'yxati; Sh5OstatkaDetailUi — bitta ombor tovarlari
// qidiruv bilan («Coca Cola 0.5L — 5 шт»). PLAN_OSTATKA bosqich 0: manba
// vaqtincha StoreHouse (bridge push qiladi), faqat KO'RISH.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart' show formatPortions;
import 'package:uz_ai_dev/admin/model/sh5_remain_model.dart';
import 'package:uz_ai_dev/admin/services/sh5_service.dart';
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
        'Hali qoldiq kelmagan.\nBridge birinchi push\'ni yuborishini kuting.',
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      final detail =
          await _service.fetchDetail(widget.sklad.id, q: _search.text);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    final taken = widget.sklad.takenAt == null
        ? null
        : DateFormat('dd.MM HH:mm').format(widget.sklad.takenAt!.toLocal());
    return Scaffold(
      backgroundColor: kRk7Bg,
      appBar: AppBar(
        backgroundColor: kRk7Accent,
        foregroundColor: Colors.white,
        title: Text(widget.sklad.name),
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
        ],
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
