import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/utils/qty_units.dart';
import 'package:uz_ai_dev/yuk/models/yuk_order_model.dart';

// Narxlangan sklad buyurtmalarini KUNLIK kartalarda ko'rsatish uchun UMUMIY
// widget va yordamchilar. Ikki ekran BIR XIL kartani ishlatadi:
//   - bugalter bosh ekrani (barcha yuk keltiruvchilar, sklad tablari bilan);
//   - yuk keltiruvchining tarix ekrani (faqat o'zining buyurtmalari, yassi
//     ro'yxat — sklad yorliqlari kun kartasi ichida).
// Farqlar parametrlar bilan boshqariladi (showImages, showSkladLabels).

// Sklad nomlari (yuk_home_ui dagi kSkladNames bilan bir xil hardcode) —
// buyurtmada sklad_name bo'sh kelsa fallback sifatida ishlatiladi.
const Map<int, String> kYukSkladNames = {
  1: 'Marxabo Sklat',
  2: 'Sardor Sklat',
  3: 'Fresco Sklat',
  4: 'Personal Sklad',
};

// Summalarni chiroyli ko'rsatish: 1000 -> "1 000" (yuk_home_ui bilan bir xil).
String formatMoney(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ─────────────── Kunlik guruhlash yordamchilari ───────────────

// Bir kunlik guruh: lokal kalendar kuni va shu kunga tegishli buyurtmalar.
class YukDayGroup {
  final DateTime day;
  final List<YukOrder> orders;
  YukDayGroup(this.day, this.orders);
}

// Buyurtma qaysi kunga tegishli: narxlangan vaqti (priced_at), bo'lmasa
// yaratilgan vaqti — LOKAL kalendar kuni sifatida.
DateTime _orderDay(YukOrder o) {
  final dt = o.pricedAt ?? DateTime.tryParse(o.created);
  if (dt == null) return DateTime(2000);
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

// Buyurtmaning ko'rsatiladigan mahsulot qatorlari: rasxod emas va
// "olinmagan"/bo'sh (taken == 0 && subtotal == 0) qatorlar tashlanadi.
List<YukOrderItem> _visibleProducts(YukOrder o) => o.items
    .where((i) => !i.isRasxod && !(i.taken == 0 && i.subtotal == 0))
    .toList();

// Buyurtma kunlik kartaga biror narsa qo'shadimi: ko'rinadigan mahsulot
// qatori, rasxod yoki nol bo'lmagan summa bo'lsa — ha. Hammasi bo'sh
// buyurtma umuman ko'rsatilmaydi.
bool yukOrderContributes(YukOrder o) =>
    _visibleProducts(o).isNotEmpty ||
    o.items.any((i) => i.isRasxod) ||
    o.total != 0;

// Buyurtmalarni kunlar bo'yicha guruhlash; kunlar kamayuvchi tartibda
// (eng yangi kun birinchi). Kun ichida kelgan tartib saqlanadi.
List<YukDayGroup> groupYukOrdersByDay(List<YukOrder> orders) {
  final map = <DateTime, List<YukOrder>>{};
  for (final o in orders) {
    map.putIfAbsent(_orderDay(o), () => []).add(o);
  }
  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final k in keys) YukDayGroup(k, map[k]!)];
}

// Fayl/URL video ekanini kengaytmasidan aniqlash (yuk_home_ui bilan bir xil).
bool _isVideoPath(String p) {
  final ext = p.split('.').last.toLowerCase();
  return const {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'}.contains(ext);
}

// Relativ /static/... URL'ni to'liq manzilga aylantirish.
String _attachmentUrl(String url) =>
    url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';

// Bitta KUN kartasi: sarlavha — faqat sana (dd.MM.yyyy, buyurtma ID va
// statussiz), shu kunning barcha buyurtmalari mahsulot qatorlari bitta
// jadvalda (jamlanmaydi, ketma-ket), xarajatlar (rasxod) kun bo'yicha
// jamlangan blok va kun yakuni (Mahsulot/Xarajat/Jami).
class YukDayCard extends StatelessWidget {
  final DateTime day;
  // Shu kunga tegishli (bo'sh bo'lmagan) buyurtmalar.
  final List<YukOrder> orders;
  // true bo'lsa buyurtmalarga biriktirilgan rasm/videolar ko'rsatiladi
  // (AppBar'dagi tugma bilan boshqariladi).
  final bool showImages;
  // Sklad almashganda kichik sklad nomi yorlig'i chiqadi (bugalter "Hammasi"
  // tabi va yuk tarixi); aniq sklad tabida kerak emas.
  final bool showSkladLabels;
  // Mahsulot qatori bosilganda tahrirlash uchun callback (bugalter miqdorni
  // tuzatishi uchun). null (default) — qatorlar faqat o'qiladi; yuk tarixi
  // ekrani shu holatda qoladi.
  final void Function(YukOrder order, YukOrderItem item)? onEditItem;
  const YukDayCard({
    super.key,
    required this.day,
    required this.orders,
    this.showImages = false,
    this.showSkladLabels = false,
    this.onEditItem,
  });

  static const Color _accent = Color(0xFFC5A97B);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    // Kun bo'yicha jami: totalSum — narxlangan to'liq summa; effectiveSum —
    // ombor kam qabul qilgan buyurtmada receivedTotal, aks holda total.
    double totalSum = 0, effectiveSum = 0, expenses = 0;
    var hasProducts = false;
    for (final o in orders) {
      final received = o.receivedTotal;
      final orderReduced =
          received > 0 && (received - o.total).abs() > 0.0001;
      totalSum += o.total.toDouble();
      effectiveSum += orderReduced ? received : o.total.toDouble();
      expenses += o.expensesTotal;
      if (_visibleProducts(o).isNotEmpty) hasProducts = true;
    }
    // Kun darajasida kamaygan bo'lsa — eski summa ustidan chizilib,
    // yangisi yashil ko'rsatiladi.
    final reduced = (effectiveSum - totalSum).abs() > 0.0001;
    // Kunning barcha buyurtmalaridagi rasxod (xarajat) qatorlari — bitta blok.
    final rasxodItems = [
      for (final o in orders) ...o.items.where((i) => i.isRasxod),
    ];
    final grandTotal = effectiveSum + expenses;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sarlavha: faqat kun sanasi (buyurtma ID va status ko'rsatilmaydi).
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: _accent),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd.MM.yyyy').format(day),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          // Jadval sarlavhasi (mahsulot qatorlari bo'lsa).
          if (hasProducts)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Mahsulot',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Soni',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Donasi',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Turi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Summa',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Kunning barcha buyurtmalari qatorlari (sklad yorlig'i,
          // biriktirmalar va mahsulotlar — kelgan tartibda, jamlanmasdan).
          ..._buildDayRows(),
          // Xarajatlar (rasxod) bloki.
          if (rasxodItems.isNotEmpty) ...[
            const Divider(height: 18),
            const Text(
              'Xarajatlar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            ...rasxodItems.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${formatMoney(item.subtotal)} so\'m',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 18),
          // Kun yakuni: Mahsulot / Xarajat (bo'lsa) / Jami. Ombor kam qabul
          // qilgan bo'lsa eski summa chizilib, effektiv summa yashil chiqadi.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mahsulot:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              if (!reduced)
                Text(
                  '${formatMoney(effectiveSum)} so\'m',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${formatMoney(totalSum)} so\'m',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _red,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: _red,
                        decorationThickness: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatMoney(effectiveSum)} so\'m',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (expenses > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Xarajat:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  '${formatMoney(expenses)} so\'m',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jami:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              Text(
                '${formatMoney(grandTotal)} so\'m',
                style: const TextStyle(
                  fontSize: 15,
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

  // Kun kartasining ichki qatorlari: har buyurtma uchun (kelgan tartibda)
  // — sklad almashsa kichik sklad yorlig'i (yoqilgan bo'lsa), buyurtma
  // biriktirmalari (rasm tugmasi yoqiq bo'lsa) va mahsulot qatorlari
  // (har qator ostida omborchi qabul paytidagi media — acceptMedia).
  List<Widget> _buildDayRows() {
    final out = <Widget>[];
    String? lastSklad;
    for (final order in orders) {
      final products = _visibleProducts(order);
      final skladName = order.skladName.isNotEmpty
          ? order.skladName
          : (kYukSkladNames[order.skladId] ?? 'Sklad ${order.skladId}');
      // Sklad yorlig'i faqat yoqilganda va sklad almashganda.
      if (showSkladLabels && skladName != lastSklad) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              children: [
                const Icon(Icons.store_outlined, size: 14, color: _accent),
                const SizedBox(width: 4),
                Text(
                  skladName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
        );
        lastSklad = skladName;
      }
      // Buyurtmaga biriktirilgan rasm/videolar (AppBar tugmasi yoqilganda).
      if (showImages && order.attachments.isNotEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: order.attachments
                  .map((e) => _AttachmentTile(entry: e))
                  .toList(),
            ),
          ),
        );
      }
      for (final item in products) {
        out.add(_productRow(order, item));
        // Omborchi qabul paytida olgan rasm/video (tugma yoqilganda).
        if (showImages && item.acceptMedia.isNotEmpty) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.acceptMedia
                    .map((e) => _AttachmentTile(entry: e, size: 56))
                    .toList(),
              ),
            ),
          );
        }
      }
    }
    return out;
  }

  // Bitta mahsulot qatori: Mahsulot / Soni / Donasi / Turi / Summa.
  // onEditItem berilgan bo'lsa qator bosiladigan bo'ladi (bugalter miqdorni
  // tuzatadi) va "Soni" yonida kichik tahrir belgisi ko'rinadi.
  Widget _productRow(YukOrder order, YukOrderItem item) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: onEditItem == null
                ? Text(
                    // taken API birlikda (кг/л -> gramm) — UI'da kg ko'rinadi.
                    formatQty(item.taken, item.type),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          formatQty(item.taken, item.type),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 6),
          // Donasi (birlik narx) = summa / soni (UI birlikda: so'm/kg).
          Expanded(
            flex: 3,
            child: Text(
              item.taken > 0 && item.subtotal > 0
                  ? '${formatMoney(item.subtotal / qtyToUi(item.taken, item.type))} so\'m'
                  : '-',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Turi (o'lchov birligi: кг, шт...).
          Expanded(
            flex: 2,
            child: Text(
              (item.type ?? '').isNotEmpty ? item.type! : '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              '${formatMoney(item.subtotal)} so\'m',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
    if (onEditItem == null) return row;
    return InkWell(
      onTap: () => onEditItem!(order, item),
      borderRadius: BorderRadius.circular(6),
      child: row,
    );
  }
}

// Bitta biriktirma plitkasi (72x72): rasm — thumbnail (bosilsa to'liq ekran),
// video — play belgisi (bosilsa tashqi pleerda ochiladi).
class _AttachmentTile extends StatelessWidget {
  final String entry;
  final double size;
  const _AttachmentTile({required this.entry, this.size = 72});

  void _open(BuildContext context) {
    if (_isVideoPath(entry)) {
      launchUrl(
        Uri.parse(_attachmentUrl(entry)),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(_attachmentUrl(entry)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _isVideoPath(entry);
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isVideo
              ? Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                )
              : Image.network(
                  _attachmentUrl(entry),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF5F1EA),
                    child: const Icon(Icons.broken_image, color: Colors.black26),
                  ),
                ),
        ),
      ),
    );
  }
}
