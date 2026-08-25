// admin/ui/sh5_handover_history_ui.dart — SH5 smena topshiriqlari tarixi:
// Sh5HandoverHistoryUi — ro'yxat (kamomad chiqqani QIZIL belgi bilan),
// Sh5HandoverDetailUi — bitta topshiriq qatorlari («faqat farq» filtri bilan).
// Ro'yxat itemlarsiz keladi (yengil), detal alohida so'raladi.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/rk7_shift_model.dart' show formatPortions;
import 'package:uz_ai_dev/admin/model/sh5_handover_model.dart';
import 'package:uz_ai_dev/admin/services/sh5_service.dart';
import 'package:uz_ai_dev/admin/ui/widgets/rk7_common.dart';
import 'package:uz_ai_dev/core/context_extension.dart';

// ─────────────────────── Tarix ro'yxati ───────────────────────

class Sh5HandoverHistoryUi extends StatefulWidget {
  // skladId null — ruxsat berilgan hamma ombor bo'yicha.
  final int? skladId;
  final String title;

  const Sh5HandoverHistoryUi({super.key, this.skladId, this.title = 'Ostatka tarixi'});

  @override
  State<Sh5HandoverHistoryUi> createState() => _Sh5HandoverHistoryUiState();
}

class _Sh5HandoverHistoryUiState extends State<Sh5HandoverHistoryUi> {
  final Sh5Service _service = Sh5Service();
  List<Sh5Handover> _rows = [];
  bool _loading = true;
  String? _error;
  int _days = 30;

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
      final rows = await _service.fetchHandovers(
          skladId: widget.skladId, days: _days);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kRk7Bg,
      appBar: AppBar(
        backgroundColor: kRk7Accent,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<int>(
            initialValue: _days,
            tooltip: 'Davr',
            onSelected: (v) {
              setState(() => _days = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('7 kun')),
              PopupMenuItem(value: 30, child: Text('30 kun')),
              PopupMenuItem(value: 90, child: Text('90 kun')),
              PopupMenuItem(value: 365, child: Text('1 yil')),
            ],
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return rk7ErrorState(_error!, onRetry: _load);
    if (_rows.isEmpty) {
      return rk7EmptyState(Icons.history, 'Hali topshiriq yo\'q');
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _card(_rows[i]),
    );
  }

  Widget _card(Sh5Handover h) {
    final out = h.outAt == null
        ? '—'
        : DateFormat('dd.MM HH:mm').format(h.outAt!.toLocal());
    final shortage = h.shortageCount + h.outShortageCount;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Sh5HandoverDetailUi(handoverId: h.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      h.skladName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (h.isOpen)
                    rk7Badge('Qabul kutilmoqda', color: Colors.orange.shade700)
                  else if (shortage > 0)
                    rk7Badge('$shortage ta kam', color: Colors.red.shade700)
                  else
                    rk7Badge('To\'g\'ri', color: Colors.green.shade700),
                ],
              ),
              const SizedBox(height: 6),
              Text('Topshirdi: ${h.outUserName} • $out',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              if (!h.isOpen)
                Text(
                  'Qabul qildi: ${h.inUserName} • '
                  '${h.inAt == null ? '—' : DateFormat('dd.MM HH:mm').format(h.inAt!.toLocal())}',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  rk7Badge('${h.itemCount} tovar', color: kRk7AccentDark),
                  if (h.outDiffCount > 0)
                    rk7Badge('StoreHouse farqi: ${h.outDiffCount}',
                        color: Colors.deepOrange.shade400),
                  if (h.inDiffCount > 0)
                    rk7Badge('Qabul farqi: ${h.inDiffCount}',
                        color: Colors.deepOrange.shade700),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Bitta topshiriq ───────────────────────

class Sh5HandoverDetailUi extends StatefulWidget {
  final int handoverId;
  const Sh5HandoverDetailUi({super.key, required this.handoverId});

  @override
  State<Sh5HandoverDetailUi> createState() => _Sh5HandoverDetailUiState();
}

class _Sh5HandoverDetailUiState extends State<Sh5HandoverDetailUi> {
  final Sh5Service _service = Sh5Service();
  Sh5Handover? _h;
  bool _loading = true;
  bool _onlyDiff = true;
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
      final h = await _service.fetchHandover(widget.handoverId,
          onlyDiff: _onlyDiff);
      if (!mounted) return;
      setState(() {
        _h = h;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kRk7Bg,
      appBar: AppBar(
        backgroundColor: kRk7Accent,
        foregroundColor: Colors.white,
        title: Text(_h?.skladName ?? 'Topshiriq'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return rk7ErrorState(_error!, onRetry: _load);
    final h = _h;
    if (h == null) return rk7EmptyState(Icons.error_outline, 'Topilmadi');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        _header(h),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _onlyDiff,
          onChanged: (v) {
            setState(() => _onlyDiff = v);
            _load();
          },
          dense: true,
          tileColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Faqat farq chiqqanlar',
              style: TextStyle(fontSize: 14)),
          activeThumbColor: kRk7AccentDark,
        ),
        const SizedBox(height: 8),
        if (h.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                _onlyDiff ? 'Farq chiqmagan — hammasi to\'g\'ri' : 'Qator yo\'q',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          )
        else
          ...h.items.map((it) => _row(h, it)),
      ],
    );
  }

  Widget _header(Sh5Handover h) {
    final out = h.outAt == null
        ? '—'
        : DateFormat('dd.MM.yyyy HH:mm').format(h.outAt!.toLocal());
    final inAt = h.inAt == null
        ? '—'
        : DateFormat('dd.MM.yyyy HH:mm').format(h.inAt!.toLocal());
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Topshirdi: ${h.outUserName}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(out, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            if (h.outNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Izoh: ${h.outNote}',
                    style: const TextStyle(fontSize: 12.5)),
              ),
            const Divider(height: 16),
            if (h.isOpen)
              Text('Hali qabul qilinmagan',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800))
            else ...[
              Text('Qabul qildi: ${h.inUserName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(inAt,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              if (h.inNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Izoh: ${h.inNote}',
                      style: const TextStyle(fontSize: 12.5)),
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                rk7Badge('${h.itemCount} tovar', color: kRk7AccentDark),
                if (h.outShortageCount > 0)
                  rk7Badge('Topshirishda kam: ${h.outShortageCount}',
                      color: Colors.red.shade600),
                if (h.shortageCount > 0)
                  rk7Badge('Qabulda kam: ${h.shortageCount}',
                      color: Colors.red.shade800),
                if (h.surplusCount > 0)
                  rk7Badge('Ortiq: ${h.surplusCount}',
                      color: Colors.green.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Sh5Handover h, Sh5HandoverItem it) {
    // Ko'rsatiladigan farq: qabul bo'lgan bo'lsa in↔out, aks holda out↔StoreHouse.
    final diff = h.isOpen ? it.outDiff : it.inDiff;
    final left = h.isOpen ? it.sh5Milli : it.outMilli;
    final right = h.isOpen ? it.outMilli : it.inMilli;
    final leftLabel = h.isOpen ? 'StoreHouse' : 'Topshirilgan';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: diff == 0
            ? Colors.white
            : (diff < 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name, style: const TextStyle(fontSize: 14)),
                Text(
                  '$leftLabel: ${formatPortions(left)} ${it.unit}'
                  '${it.prevOutMilli > 0 ? '  •  oldingi: ${formatPortions(it.prevOutMilli)}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatPortions(right)} ${it.unit}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              if (diff != 0)
                Text(
                  '${diff > 0 ? '+' : '−'}${formatPortions(diff.abs())}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color:
                        diff < 0 ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
