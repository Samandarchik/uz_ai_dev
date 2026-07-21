// yuk/ui/yuk_history_ui.dart — yuk keltiruvchining O'ZI narxlagan buyurtmalari tarixi ekrani:
// YukHistoryUi. YukProvider.myHistoryOrders'ni YukDayCard kunlik kartalarida ko'rsatadi
// (backenddan ?status=done bilan yuklanadi).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';
import 'package:uz_ai_dev/yuk/ui/widgets/yuk_day_cards.dart';

// Yuk keltiruvchining O'ZI narxlagan buyurtmalari tarixi — bugalter bosh
// ekranidagi bilan BIR XIL kunlik kartalar (YukDayCard): kun = narxlangan
// vaqt (priced_at, bo'lmasa created) lokal sanasi, eng yangi kun tepada;
// kun ichida sklad yorliqlari, mahsulot qatorlari, xarajatlar (rasxod)
// bloki va kun yakuni (Mahsulot/Xarajat/Jami). Ombor kam qabul qilgan kunda
// eski summa qizil chizilib, yangisi yashil chiqadi.
// Faqat o'zi yuborganlar ko'rinadi: priced_by == men (yoki 0 — egasi
// yozilmagan eski buyurtmalar). Asosiy sahifadagi tarix tugmasidan ochiladi;
// ro'yxat backenddan alohida (?status=done) yuklanadi.
class YukHistoryUi extends StatefulWidget {
  // Asosiy sahifadan keladi (eski sklad tablari uchun edi); ro'yxat endi
  // yassi — faqat "sklad biriktirilmagan" holatini ko'rsatishda ishlatiladi.
  final List<int> sklads;
  const YukHistoryUi({super.key, required this.sklads});

  @override
  State<YukHistoryUi> createState() => _YukHistoryUiState();
}

class _YukHistoryUiState extends State<YukHistoryUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  // AppBar'dagi tugma bilan yoqiladi: buyurtmaga biriktirilgan
  // rasm/videolarni kunlik kartada ko'rsatish (bugalter bilan bir xil).
  bool _showImages = false;

  @override
  void initState() {
    super.initState();
    // Ekran ochilganda tarixni serverdan olamiz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<YukProvider>().fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Yuborilganlar tarixi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _showImages
                ? 'Rasmlarni yashirish'
                : 'Rasmlarni ko\'rsatish',
            onPressed: () => setState(() => _showImages = !_showImages),
            icon: Icon(
              _showImages ? Icons.image : Icons.image_outlined,
              color: _showImages ? _accentColor : null,
            ),
          ),
        ],
      ),
      body: widget.sklads.isEmpty
          ? const Center(
              child: Text(
                'Sizga hech qanday sklad biriktirilmagan',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : Consumer<YukProvider>(
              builder: (context, provider, child) {
                if (provider.isHistoryLoading &&
                    provider.historyOrders.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                if (provider.historyError != null &&
                    provider.historyOrders.isEmpty) {
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
                            provider.historyError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => provider.fetchHistory(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Qayta urinish'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Faqat o'zim narxlagan (yoki egasi yozilmagan eski)
                // buyurtmalar; bo'sh (hech narsa ko'rsatmaydigan)
                // buyurtmalar tashlanib, lokal kalendar kuni bo'yicha
                // guruhlanadi (bugalter bilan bir xil).
                final days = groupYukOrdersByDay(provider.myHistoryOrders
                    .where(yukOrderContributes)
                    .toList());
                return RefreshIndicator(
                  color: _accentColor,
                  onRefresh: () => provider.fetchHistory(),
                  child: days.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Tarix bo\'sh',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: days.length,
                          itemBuilder: (context, index) {
                            final day = days[index];
                            return YukDayCard(
                              key: ValueKey(day.day),
                              day: day.day,
                              orders: day.orders,
                              showImages: _showImages,
                              // Kun ichida sklad almashganda kichik sklad
                              // nomi yorlig'i ko'rsatiladi.
                              showSkladLabels: true,
                            );
                          },
                        ),
                );
              },
            ),
    );
  }
}
