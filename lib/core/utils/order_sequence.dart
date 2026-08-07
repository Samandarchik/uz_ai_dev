// core/utils/order_sequence.dart — buyurtma ro'yxatlarining YAGONA ketma-ketligi.
//
// Muammo: bir xil buyurtmalar har ekranda boshqa tartibda chiqardi —
// omborchi ekrani `id` bo'yicha KAMAYUVCHI (yangisi tepada), yuk keltiruvchi
// bosh ekrani `created` bo'yicha O'SUVCHI, yuk tarixi va bugalter esa
// `created` bo'yicha kamayuvchi. Natijada omborchi bilan yuk keltiruvchi
// bitta kunning mahsulotlarini boshqa-boshqa ketma-ketlikda ko'rib,
// bir-birini tekshira olmasdi.
//
// QOIDA (hamma ekran uchun bitta): buyurtmalar YARATILGAN vaqti bo'yicha
// O'SUVCHI tartibda — birinchi berilgani tepada, keyingilari pastida. Vaqt
// teng bo'lsa (bitta savat source bo'yicha bir necha buyurtmaga bo'linganda
// hammasi bir lahzada yaratiladi) — `id` bo'yicha. Shu bilan ro'yxat aynan
// omborchi savatga qo'shgan tartibda chiqadi va yuk keltiruvchida ham,
// bugalterda ham xuddi shunday ko'rinadi.
//
// Kunlar bo'yicha guruhlash (`groupYukOrdersByDay`) o'zgarmaydi — u yerda
// yangi KUN tepada qoladi, tartib faqat kun/karta ICHIDA qo'llanadi.

/// Ikki buyurtmani yagona qoida bo'yicha solishtiradi (created ASC, keyin id).
int compareOrderSeq(String createdA, int idA, String createdB, int idB) {
  final da = DateTime.tryParse(createdA);
  final db = DateTime.tryParse(createdB);
  if (da != null && db != null) {
    final c = da.compareTo(db);
    if (c != 0) return c;
  } else if (da == null && db != null) {
    return 1; // sanasi o'qilmagani oxirida
  } else if (da != null && db == null) {
    return -1;
  }
  return idA.compareTo(idB);
}

/// Ro'yxatni joyida (in-place) yagona qoida bo'yicha tartiblaydi.
void sortOrderSeq<T>(
  List<T> list, {
  required String Function(T) createdOf,
  required int Function(T) idOf,
}) {
  list.sort((a, b) =>
      compareOrderSeq(createdOf(a), idOf(a), createdOf(b), idOf(b)));
}

/// Bitta buyurtma ICHIDAGI qatorlar tartibi: avval omborchi buyurtma qilgan
/// katalog itemlari (serverdagi tartibda — savatga qo'shilgan ketma-ketlik),
/// keyin yuk keltiruvchi qo'lda qo'shgan «proche» yozuvlari. Yuk ekrani
/// allaqachon shunday chizardi, omborchi ekrani esa massiv tartibida — endi
/// ikkalasi ham shu funksiyadan o'tadi.
///
/// Rasxod (xarajat) qatorlari alohida blokda ko'rsatilgani uchun bu yerga
/// KIRMAYDI — chaqiruvchi ularni oldindan filtrlaydi.
List<T> orderItemSeq<T>(
  Iterable<T> items, {
  required bool Function(T) isProche,
}) {
  final catalog = <T>[];
  final proche = <T>[];
  for (final it in items) {
    (isProche(it) ? proche : catalog).add(it);
  }
  return [...catalog, ...proche];
}

/// Yangi tartiblangan nusxa qaytaradi (asl ro'yxatga tegmaydi).
List<T> sortedOrderSeq<T>(
  Iterable<T> list, {
  required String Function(T) createdOf,
  required int Function(T) idOf,
}) {
  final copy = List<T>.of(list);
  sortOrderSeq(copy, createdOf: createdOf, idOf: idOf);
  return copy;
}
