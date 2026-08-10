// admin/ui/delivery_ui.dart — Яндекс/Узум yetkazib berish daftari ekrani
// (DeliveryUi): «Программа.xlsx» o'rnini bosadi. Platforma tablari (kunlik
// yozuvlar: zakaz soni/chek/zakaz summa/to'lov, avto komissiya va ostatok,
// qarz kartasi) + «Hisobot» tabi (oylik jamlanma). Admin menyudan ochiladi.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/services/delivery_service.dart';

String _som(int v) => '${NumberFormat('#,###').format(v)} so\'m';

class DeliveryUi extends StatefulWidget {
  const DeliveryUi({super.key});

  @override
  State<DeliveryUi> createState() => _DeliveryUiState();
}

class _DeliveryUiState extends State<DeliveryUi>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yetkazib berish'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Яндекс'),
            Tab(text: 'Узум'),
            Tab(text: 'Hisobot'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _PlatformTab(platform: 'yandex', title: 'Яндекс'),
          _PlatformTab(platform: 'uzum', title: 'Узум'),
          _SummaryTab(),
        ],
      ),
    );
  }
}

// ─────────────────────── Platforma tabi ───────────────────────

class _PlatformTab extends StatefulWidget {
  final String platform;
  final String title;

  const _PlatformTab({required this.platform, required this.title});

  @override
  State<_PlatformTab> createState() => _PlatformTabState();
}

class _PlatformTabState extends State<_PlatformTab>
    with AutomaticKeepAliveClientMixin {
  final DeliveryService _service = DeliveryService();
  DateTime _month = DateTime.now();
  DeliveryMonth? _data;
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  String get _monthStr =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

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
      final d = await _service.fetchMonth(widget.platform, _monthStr);
      if (!mounted) return;
      setState(() {
        _data = d;
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

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  // Oy kunlari ro'yxati: mavjud yozuvlar + bo'sh kunlar (bugungacha).
  List<String> _monthDates() {
    final now = DateTime.now();
    final last = (_month.year == now.year && _month.month == now.month)
        ? now.day
        : DateTime(_month.year, _month.month + 1, 0).day;
    return [
      for (var d = 1; d <= last; d++)
        '$_monthStr-${d.toString().padLeft(2, '0')}'
    ];
  }

  Future<void> _editDay(String date, DeliveryDay? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DayEditDialog(
        service: _service,
        platform: widget.platform,
        title: widget.title,
        date: date,
        existing: existing,
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    final d = _data!;
    final byDate = {for (final x in d.days) x.date: x};
    final dates = _monthDates();
    const monthNames = ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
      'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];
    final monthLabel = '${monthNames[_month.month - 1]} ${_month.year}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Qarz kartasi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: d.debt > 0 ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: d.debt > 0
                      ? Colors.orange.shade200
                      : Colors.green.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.title} qarz qoldig\'i',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(_som(d.debt),
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text('komissiya ${d.commissionPercent}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Oy tanlagich
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1)),
              Text(monthLabel,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftMonth(1)),
            ],
          ),
          // Jami qatori
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Jami: ${d.totals['orders'] ?? 0} zakaz, '
              '${_som(d.totals['order_sum'] ?? 0)}; '
              'to\'landi ${_som(d.totals['payments'] ?? 0)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // Sarlavha
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(children: [
              SizedBox(width: 44, child: Text('Kun', style: _kHead)),
              Expanded(
                  child: Text('Zakaz', style: _kHead,
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('Summa', style: _kHead,
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('Ostatok', style: _kHead,
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('To\'lov', style: _kHead,
                      textAlign: TextAlign.right)),
            ]),
          ),
          ...dates.reversed.map((date) {
            final day = byDate[date];
            final empty = day == null || (day.orders == 0 && day.orderSum == 0 && day.payment == 0);
            return InkWell(
              onTap: () => _editDay(date, day),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  SizedBox(
                      width: 44,
                      child: Text(date.substring(8),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: empty ? Colors.grey : Colors.black87))),
                  Expanded(
                      child: Text(empty ? '—' : '${day.orders}',
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(
                          empty ? '—' : NumberFormat('#,###').format(day.orderSum),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(
                          empty ? '—' : NumberFormat('#,###').format(day.ostatok),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.grey.shade700))),
                  Expanded(
                      flex: 2,
                      child: Text(
                          day == null || day.payment == 0
                              ? '—'
                              : NumberFormat('#,###').format(day.payment),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600))),
                ]),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

const _kHead = TextStyle(fontSize: 11, color: Colors.grey);

// ─────────────────────── Kun tahriri dialogi ───────────────────────

class _DayEditDialog extends StatefulWidget {
  final DeliveryService service;
  final String platform;
  final String title;
  final String date;
  final DeliveryDay? existing;

  const _DayEditDialog({
    required this.service,
    required this.platform,
    required this.title,
    required this.date,
    required this.existing,
  });

  @override
  State<_DayEditDialog> createState() => _DayEditDialogState();
}

class _DayEditDialogState extends State<_DayEditDialog> {
  late final TextEditingController _orders;
  late final TextEditingController _check;
  late final TextEditingController _order;
  late final TextEditingController _payment;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _orders = TextEditingController(
        text: e == null || e.orders == 0 ? '' : '${e.orders}');
    _check = TextEditingController(
        text: e == null || e.checkSum == 0 ? '' : '${e.checkSum}');
    _order = TextEditingController(
        text: e == null || e.orderSum == 0 ? '' : '${e.orderSum}');
    _payment = TextEditingController(
        text: e == null || e.payment == 0 ? '' : '${e.payment}');
  }

  @override
  void dispose() {
    _orders.dispose();
    _check.dispose();
    _order.dispose();
    _payment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.saveDay(
        platform: widget.platform,
        date: widget.date,
        orders: int.tryParse(_orders.text.trim()) ?? 0,
        checkSum: int.tryParse(_check.text.trim()) ?? 0,
        orderSum: int.tryParse(_order.text.trim()) ?? 0,
        payment: int.tryParse(_payment.text.trim()) ?? 0,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.title} — ${widget.date.substring(8)}.'
          '${widget.date.substring(5, 7)}.${widget.date.substring(0, 4)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_orders, 'Zakazlar soni'),
            _field(_check, 'Chek summa (so\'m)'),
            _field(_order, 'Zakaz summa (so\'m)'),
            _field(_payment, 'To\'lov keldi (so\'m)'),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}

// ─────────────────────── Hisobot tabi ───────────────────────

class _SummaryTab extends StatefulWidget {
  const _SummaryTab();

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab>
    with AutomaticKeepAliveClientMixin {
  final DeliveryService _service = DeliveryService();
  List<DeliveryMonthAgg>? _months;
  Map<String, int> _debts = {};
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (months, debts) = await _service.fetchSummary();
      if (!mounted) return;
      setState(() {
        _months = months;
        _debts = debts;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) return Center(child: Text(_error!));
    final months = _months;
    if (months == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(child: _debtCard('Яндекс', _debts['yandex'] ?? 0)),
            const SizedBox(width: 8),
            Expanded(child: _debtCard('Узум', _debts['uzum'] ?? 0)),
          ]),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(children: [
              SizedBox(width: 64, child: Text('Oy', style: _kHead)),
              Expanded(
                  flex: 3,
                  child: Text('Яндекс', style: _kHead,
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 3,
                  child:
                      Text('Узум', style: _kHead, textAlign: TextAlign.right)),
              Expanded(
                  flex: 3,
                  child:
                      Text('Jami', style: _kHead, textAlign: TextAlign.right)),
            ]),
          ),
          ...months.reversed.map((m) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  SizedBox(
                      width: 64,
                      child: Text(m.month,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600))),
                  Expanded(
                      flex: 3,
                      child: Text(
                          NumberFormat('#,###')
                              .format(m.sums['yandex'] ?? 0),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 3,
                      child: Text(
                          NumberFormat('#,###')
                              .format(m.sums['uzum'] ?? 0),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 3,
                      child: Text(
                          NumberFormat('#,###').format(m.total),
                          textAlign: TextAlign.right,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _debtCard(String title, int debt) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: debt > 0 ? Colors.orange.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  debt > 0 ? Colors.orange.shade200 : Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title qarzi',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(_som(debt),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
