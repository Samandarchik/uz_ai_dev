import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/yuk/models/yuk_ledger_model.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';

// Yuk keltiruvchi profili — kunlik hisob daftari, Excel jadval ko'rinishida.
// Har oy alohida bo'lim: sarlavha ("Iyul 2026") + jadval. Jadvalda oyning
// HAR BIR kuni (1 → oy oxiri; joriy oyda bugungacha) alohida qator:
//   Sana | Ertalab | Prixod | Rasxod | Ostatok
// Ertalab=opening, Prixod=prixod, Rasxod=yuborilgan (faqat balansga kirgani),
// Ostatok=closing — shunda Ostatok = Ertalab + Prixod − Rasxod ko'rinib turadi.
// Yozuvi bor kun bosilsa o'sha kunning xarajat tafsiloti (bottom sheet) ochiladi.
class YukProfileUi extends StatefulWidget {
  const YukProfileUi({super.key});

  @override
  State<YukProfileUi> createState() => _YukProfileUiState();
}

class _YukProfileUiState extends State<YukProfileUi> {
  static const Color _bg = Color(0xFFFAF6F1);
  static const Color _accent = Color(0xFFC5A97B);

  @override
  void initState() {
    super.initState();
    // Ekran ochilganda hisob daftarini yuklaymiz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<YukProvider>().fetchLedger();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<YukProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingLedger && provider.ledger.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.ledgerError != null && provider.ledger.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      provider.ledgerError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchLedger(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sections = _buildMonths(provider.ledger, DateTime.now());

          return RefreshIndicator(
            color: _accent,
            onRefresh: () => provider.fetchLedger(),
            child: sections.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Hisob yozuvlari yo\'q',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Oxirgi qator tizim navigatsiya paneli ostida qolmasligi uchun
                    // pastdan qo'shimcha bo'sh joy.
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      12 + MediaQuery.of(context).padding.bottom + 80,
                    ),
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return _MonthTable(
                        key: ValueKey('${section.year}-${section.month}'),
                        section: section,
                        onDayTap: (day) => _showDaySheet(context, day),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  // Ledger yozuvlarini (yil, oy) bo'yicha guruhlash — eng yangi oy birinchi.
  // Har oy uchun HAMMA kunlar (yozuvi yo'q kun null bo'lib) tayyorlanadi.
  List<_MonthSection> _buildMonths(List<YukLedgerDay> ledger, DateTime now) {
    final byDate = <String, YukLedgerDay>{};
    final monthKeys = <int>{}; // yil * 12 + (oy - 1)
    for (final d in ledger) {
      final dt = DateTime.tryParse(d.date);
      if (dt == null) continue;
      byDate[d.date] = d;
      monthKeys.add(dt.year * 12 + (dt.month - 1));
    }

    final sorted = monthKeys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final k in sorted) _monthOf(k ~/ 12, k % 12 + 1, byDate, now),
    ];
  }

  _MonthSection _monthOf(
    int year,
    int month,
    Map<String, YukLedgerDay> byDate,
    DateTime now,
  ) {
    final isCurrent = year == now.year && month == now.month;
    // Joriy oyda faqat bugungacha; o'tgan oylarda oy oxirigacha.
    final lastDay = isCurrent ? now.day : DateTime(year, month + 1, 0).day;
    return _MonthSection(
      year: year,
      month: month,
      days: [
        for (var d = 1; d <= lastDay; d++) byDate[_dateKey(year, month, d)],
      ],
    );
  }

  // Kun tafsiloti bottom sheet'i: kunda pul nimaga sarflangani.
  void _showDaySheet(BuildContext context, YukLedgerDay day) {
    final provider = context.read<YukProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (sheetContext, scrollController) => _LedgerDaySheet(
          day: day,
          scrollController: scrollController,
          fetch: () => provider.fetchLedgerDay(day.date),
        ),
      ),
    );
  }
}

// Bitta oyning tayyorlangan ma'lumoti: days[0] — 1-kun (yozuvi bo'lmasa null).
class _MonthSection {
  final int year;
  final int month;
  final List<YukLedgerDay?> days;

  const _MonthSection({
    required this.year,
    required this.month,
    required this.days,
  });
}

// Bitta oy bo'limi: sarlavha + Excel'dagi kabi jadval. Yozuvi bor qator
// bosiladi (kun tafsiloti ochiladi), bo'sh qator bosilmaydi.
class _MonthTable extends StatelessWidget {
  final _MonthSection section;
  final ValueChanged<YukLedgerDay> onDayTap;

  const _MonthTable({
    super.key,
    required this.section,
    required this.onDayTap,
  });

  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);
  static const Color _orange = Color(0xFFB26A00);
  // Bugungi qator foni (accent 8% shaffoflikda).
  static const Color _todayBg = Color(0x14C5A97B);
  static const Color _rowBorder = Color(0xFFF0EBE3);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        section.year == now.year && section.month == now.month;
    // Bugungi kunning yozuvi (qoralama eslatmasi uchun).
    final todayDay = (isCurrentMonth && now.day <= section.days.length)
        ? section.days[now.day - 1]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            '${_kMonths[section.month - 1]} ${section.year}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _headerRow(),
              for (var d = 1; d <= section.days.length; d++)
                _dayRow(
                  d,
                  section.days[d - 1],
                  isToday: isCurrentMonth && d == now.day,
                  isLast: d == section.days.length,
                ),
            ],
          ),
        ),
        // Bugungi yuborilmagan (qoralama) pullar — jadvaldagi Rasxod ustuniga
        // KIRMAYDI, faqat eslatma sifatida ko'rsatiladi.
        if (todayDay != null && todayDay.rasxod > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              'Yuborilmagan (qoralama): ${_money(todayDay.rasxod)} so\'m — '
              'Rasxod ustuniga kirmaydi',
              style: const TextStyle(fontSize: 11, color: _orange),
            ),
          ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _headerRow() {
    const style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Colors.black45,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _rowBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 46, child: Text('Sana', style: style)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Ertalab', style: style),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Prixod', style: style),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Rasxod', style: style),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Ostatok', style: style),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(
    int dayNum,
    YukLedgerDay? day, {
    required bool isToday,
    required bool isLast,
  }) {
    final weekday =
        DateTime(section.year, section.month, dayNum).weekday; // 1=Du..7=Ya
    final hasData = day != null;

    return Material(
      color: isToday ? _todayBg : Colors.transparent,
      child: InkWell(
        // Faqat yozuvi bor kun bosiladi — tafsilot ochiladi.
        onTap: hasData ? () => onDayTap(day) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: _rowBorder)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$dayNum ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasData ? Colors.black87 : Colors.black38,
                        ),
                      ),
                      TextSpan(
                        text: _kWeekdays[weekday - 1],
                        style: TextStyle(
                          fontSize: 9,
                          color: weekday == 7 ? _red : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _moneyCell(day?.opening, Colors.black87),
              _moneyCell(day?.prixod, _green),
              // Rasxod ustuni = FAQAT yuborilgan (balansga kirgan) summa —
              // shunda Ostatok = Ertalab + Prixod − Rasxod aynan chiqadi.
              _moneyCell(day?.yuborilgan, _red),
              _moneyCell(day?.closing, Colors.black87, bold: true),
            ],
          ),
        ),
      ),
    );
  }

  // Bitta summa katakchasi. null — bo'sh kun (—); 0 — kulrang; manfiy — qizil.
  Widget _moneyCell(num? v, Color color, {bool bold = false}) {
    final Color effective = v == null
        ? Colors.black26
        : v < 0
            ? _red
            : v == 0
                ? Colors.black38
                : color;
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              v == null ? '—' : _money(v),
              style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: effective,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────── Kun tafsiloti bottom sheet ───────────────
// "7-iyul — Rasxod": kun jami (yuborilgan) + har buyurtma bo'yicha
// nimaga pul sarflangani. Yuborilmagan qoralamalar alohida bo'limda.
class _LedgerDaySheet extends StatefulWidget {
  final YukLedgerDay day;
  final ScrollController scrollController;
  final Future<LedgerDayDetail> Function() fetch;

  const _LedgerDaySheet({
    required this.day,
    required this.scrollController,
    required this.fetch,
  });

  @override
  State<_LedgerDaySheet> createState() => _LedgerDaySheetState();
}

class _LedgerDaySheetState extends State<_LedgerDaySheet> {
  static const Color _accent = Color(0xFFC5A97B);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);
  static const Color _orange = Color(0xFFB26A00);
  static const Color _blockBg = Color(0xFFF7F4EF);

  late Future<LedgerDayDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetch();
  }

  void _retry() {
    setState(() => _future = widget.fetch());
  }

  String get _title {
    final dt = DateTime.tryParse(widget.day.date);
    if (dt == null) return '${widget.day.date} — Rasxod';
    return '${dt.day}-${_kMonthsLower[dt.month - 1]} — Rasxod';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Tortish dastagi.
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: FutureBuilder<LedgerDayDetail>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }
                if (snapshot.hasError) {
                  return ListView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 24),
                      const Icon(Icons.error_outline, color: _red, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _red, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _retry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Qayta urinish'),
                        ),
                      ),
                    ],
                  );
                }
                return _content(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(LedgerDayDetail detail) {
    final done = detail.doneOrders;
    final drafts = detail.draftOrders;
    num draftSum = 0;
    for (final o in drafts) {
      draftSum += o.itemsSum;
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          _title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // Kun jami — faqat yuborilgan (balansga kirgan) rasxod.
        Text(
          '${_money(detail.yuborilgan)} so\'m',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _red,
          ),
        ),
        const Text(
          'Kunlik rasxod (yuborilgan)',
          style: TextStyle(fontSize: 11, color: Colors.black45),
        ),
        const SizedBox(height: 16),
        if (done.isEmpty && drafts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Bu kunda buyurtmalar yo\'q',
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
            ),
          ),
        for (final order in done) _orderBlock(order, draft: false),
        if (drafts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Yuborilmagan (qoralama)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _orange,
                  ),
                ),
              ),
              Text(
                '${_money(draftSum)} so\'m',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _orange,
                ),
              ),
            ],
          ),
          const Text(
            'Kun jamiga kirmaydi — yuborilganda Rasxodga o\'tadi',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          for (final order in drafts) _orderBlock(order, draft: true),
        ],
        if (detail.prixod > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4EA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Prixod (berilgan pul)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
                Text(
                  '+${_money(detail.prixod)} so\'m',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Bitta buyurtma bloki: sklad nomi + vaqt (+ qoralama belgisi), itemlar,
  // rasxod itemlar "Xarajatlar" ostida, oxirida "Jami".
  Widget _orderBlock(LedgerDayOrder order, {required bool draft}) {
    final catalog = [
      for (final it in order.items)
        if (!it.isRasxod) it,
    ];
    final expenses = [
      for (final it in order.items)
        if (it.isRasxod) it,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blockBg,
        borderRadius: BorderRadius.circular(10),
        border: draft
            ? Border.all(color: _orange.withAlpha(90))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.skladName.isEmpty ? order.orderId : order.skladName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (draft) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1DE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Yuborilmagan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _time(order.displayTime),
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final it in catalog) _itemRow(it),
          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Xarajatlar',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 2),
            for (final it in expenses) _itemRow(it),
          ],
          const Divider(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Jami',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              Text(
                '${_money(order.itemsSum)} so\'m',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemRow(LedgerDayItem it) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              it.name,
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ),
          if (it.taken > 0) ...[
            Text(
              // taken API birlikda (кг/л -> gramm) — UI'da kg ko'rinadi.
              '× ${formatQtyUnit(it.taken, it.type)}',
              style: const TextStyle(fontSize: 11.5, color: Colors.black45),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '${_money(it.subtotal)} so\'m',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Mahalliy vaqt "HH:mm" ko'rinishida (vaqt bo'lmasa bo'sh).
  static String _time(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────── Umumiy yordamchilar ───────────────

// O'zbekcha oy nomlari (sarlavha uchun) va kichik harfda ("7-iyul" uchun).
const List<String> _kMonths = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];
const List<String> _kMonthsLower = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

// Hafta kunlari qisqartmasi: 1=Dushanba ... 7=Yakshanba.
const List<String> _kWeekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

// "YYYY-MM-DD" kalit (ledger date formati bilan bir xil).
String _dateKey(int year, int month, int day) {
  final m = month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  return '$year-$m-$d';
}

// Minglik ajratgich bilan summa: 1234567 -> "1 234 567".
String _money(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  var start = 0;
  if (s.startsWith('-')) {
    buf.write('-');
    start = 1;
  }
  final digits = s.substring(start);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}
