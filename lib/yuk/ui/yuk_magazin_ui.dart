import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/yuk/models/magazin_model.dart';
import 'package:uz_ai_dev/yuk/provider/magazin_provider.dart';
import 'package:uz_ai_dev/yuk/ui/widgets/magazin_form_sheet.dart';
import 'package:uz_ai_dev/yuk/ui/widgets/yuk_day_cards.dart' show formatMoney;
import 'package:uz_ai_dev/yuk/ui/yuk_magazin_detail_ui.dart';

// "Qarz daftari" — yuk keltiruvchi (bozorchi) qaysi magazinchilarga qarzdor
// ekanini yuritadigan ro'yxat ekrani. Tepada UMUMIY qarz doim ko'rinib
// turadi, ostida magazin kartalari (rasm, do'kon nomi, egasi, telefon,
// shu magazinga qarz). "+" FAB — yangi magazin qo'shish; karta bosilsa —
// tafsilot (qarz yozuvlari) ekrani.
class YukMagazinUi extends StatelessWidget {
  const YukMagazinUi({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider EKRANGA LOKAL: qarz daftari faqat shu ekranlar uchun kerak,
    // global main.dart ro'yxatini shishirmaymiz. Tafsilot ekraniga xuddi shu
    // instans ChangeNotifierProvider.value bilan uzatiladi.
    return ChangeNotifierProvider(
      create: (_) => MagazinProvider()..fetchMagazins(),
      child: const _MagazinListView(),
    );
  }
}

class _MagazinListView extends StatelessWidget {
  const _MagazinListView();

  static const Color _bg = Color(0xFFFAF6F1);
  static const Color _accent = Color(0xFFC5A97B);
  static const Color _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Qarz daftari',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          tooltip: 'Magazin qo\'shish',
          onPressed: () => showMagazinFormSheet(
            context,
            context.read<MagazinProvider>(),
          ),
          child: const Icon(Icons.add),
        ),
      ),
      body: Consumer<MagazinProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.magazins.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.errorMessage != null && provider.magazins.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => provider.fetchMagazins(),
                      child: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // UMUMIY qarz — ro'yxat aylantirilsa ham DOIM tepada turadi.
              _totalCard(provider.totalDebt),
              Expanded(
                child: RefreshIndicator(
                  color: _accent,
                  onRefresh: () => provider.fetchMagazins(),
                  child: provider.magazins.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Hozircha magazin qo\'shilmagan.\n'
                                'Pastdagi "+" tugmasi bilan qo\'shing.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(
                              left: 12, right: 12, bottom: 80),
                          itemCount: provider.magazins.length,
                          itemBuilder: (context, i) =>
                              _MagazinCard(magazin: provider.magazins[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Tepadagi "Jami qarz" kartasi.
  Widget _totalCard(double total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: _red, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jami qarz',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatMoney(total)} so\'m',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Bitta magazin kartasi: dumaloq rasm (yo'q bo'lsa do'kon belgisi),
// do'kon nomi qalin, ostida egasi + telefon, o'ngda shu magazinga qarz.
class _MagazinCard extends StatelessWidget {
  final Magazin magazin;
  const _MagazinCard({required this.magazin});

  static const Color _accent = Color(0xFFC5A97B);
  static const Color _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final m = magazin;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Tafsilot ekraniga SHU provider instansi uzatiladi — qarz
          // qo'shilganda ro'yxat va umumiy jami darhol yangilanadi.
          final provider = context.read<MagazinProvider>();
          context.push(
            ChangeNotifierProvider.value(
              value: provider,
              child: YukMagazinDetailUi(magazin: m),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFF0E8DC),
                backgroundImage: m.imageUrl.isNotEmpty
                    ? NetworkImage(magazinFullImageUrl(m.imageUrl))
                    : null,
                child: m.imageUrl.isEmpty
                    ? const Icon(Icons.storefront_outlined,
                        color: _accent, size: 26)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.shopName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (m.name.isNotEmpty) m.name,
                        if (m.phone.isNotEmpty) m.phone,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatMoney(m.totalDebt)} so\'m',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
