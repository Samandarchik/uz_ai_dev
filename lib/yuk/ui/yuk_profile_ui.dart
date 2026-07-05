import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/yuk/models/yuk_ledger_model.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';

// Yuk keltiruvchi profili — kunlik hisob daftari.
// Har kun bitta yopiq karta (eng yangi kun tepada); bosilganda ochilib
// ertalabgi ostatok / rasxod / prixod / kechki ostatok ko'rsatiladi.
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

          return RefreshIndicator(
            color: _accent,
            onRefresh: () => provider.fetchLedger(),
            child: provider.ledger.isEmpty
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
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.ledger.length,
                    itemBuilder: (context, index) {
                      final day = provider.ledger[index];
                      return _LedgerDayCard(
                        key: ValueKey(day.date),
                        day: day,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

// Bitta kunning kartasi: sarlavha = sana, ochilganda 4 qator summa.
class _LedgerDayCard extends StatelessWidget {
  final YukLedgerDay day;
  const _LedgerDayCard({super.key, required this.day});

  static const Color _accent = Color(0xFFC5A97B);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      // ExpansionTile'ning ochilgandagi chiziqlarini olib tashlaymiz.
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          iconColor: _accent,
          collapsedIconColor: Colors.black45,
          leading: const Icon(Icons.calendar_today_outlined,
              size: 20, color: _accent),
          title: Text(
            day.date,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            _row('Ertalabgi ostatok', day.opening, Colors.black87),
            _row('Rasxod', day.rasxod, _red),
            _row('Prixod', day.prixod, _green),
            _row('Kechki ostatok', day.closing, Colors.black87, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, num value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            '${_money(value)} so\'m',
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
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
