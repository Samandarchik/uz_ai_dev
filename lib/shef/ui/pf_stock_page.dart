// shef/ui/pf_stock_page.dart — «Полуфабрикат qoldig'i» ekrani: PfStockPage —
// shef skladidagi pf'lar ro'yxati KATEGORIYA bo'yicha guruhlangan holda
// (category_group.dart; Bor / Band / Mumkin ustunlari, qidiruv, tugaganlari
// qizil bilan). GET /api/production/pf-stock, ShefProvider ustida.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/widgets/app_network_image.dart';
import 'package:uz_ai_dev/shef/model/production_model.dart';
import 'package:uz_ai_dev/shef/provider/shef_provider.dart';
import 'package:uz_ai_dev/shef/ui/widgets/category_group.dart';

// Shef uchun полуфабрикат qoldig'i: qaysi pf bor, nechtadan bor, nechtasi
// band (boshqa buyurtmalarga), nechtasini ishlatish mumkin.
// Buyurtmaga bog'liq emas — umumiy sklad ko'rinishi.
// Ro'yxat kategoriya sarlavhalari ostida guruhlanadi (bitta kategoriya bo'lsa
// sarlavha chiqmaydi). Guruhlash har build'da emas — faqat qoldiq ro'yxati yoki
// qidiruv o'zgarganda hisoblanib keshlanadi (`_rebuildGroups`), ListView esa
// yassi (flat) indeks ustida chizadi.
class PfStockPage extends StatefulWidget {
  const PfStockPage({super.key});

  @override
  State<PfStockPage> createState() => _PfStockPageState();
}

class _PfStockPageState extends State<PfStockPage> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Guruhlash keshi ──────────────────────────────────────────────────────
  // Manba ro'yxat (identity) va qidiruv matni o'zgarmaguncha qayta hisoblamaymiz.
  List<PfStockRow>? _groupsSource;
  String _groupsQuery = '';
  // Yassi (flat) ro'yxat: CategoryHeader | PfStockRow elementlari.
  List<Object> _entries = const [];
  // Filtrdan keyingi qatorlar soni (bo'shligini tekshirish uchun).
  int _rowCount = 0;
  // Qoldig'i tugaganlar soni — xulosa qatori uchun (filtrdan mustaqil).
  int _emptyCount = 0;

  // Faqat manba/qidiruv o'zgarganda ishlaydi (build ichidan chaqiriladi, lekin
  // setState qilmaydi — bu shunchaki kesh).
  void _rebuildGroups(List<PfStockRow> source, String query) {
    if (identical(_groupsSource, source) && _groupsQuery == query) return;
    _groupsSource = source;
    _groupsQuery = query;

    final rows = query.isEmpty
        ? source
        : source.where((r) => r.name.toLowerCase().contains(query)).toList();
    _rowCount = rows.length;
    _emptyCount = source.where((r) => r.isEmptyStock).length;
    _entries = buildCategoryEntries<PfStockRow>(
      rows,
      categoryId: (r) => r.categoryId,
      categoryName: (r) => r.categoryName,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShefProvider>().fetchPfStock();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: const Text(
          'Полуфабрикат qoldig\'i',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Jami soni — ro'yxat yuklanganda ko'rinadi (qidiruvdan mustaqil).
          Selector<ShefProvider, int>(
            selector: (_, p) => p.pfStock.length,
            builder: (context, total, _) => total == 0
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        '$total ta',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Consumer<ShefProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingPfStock && provider.pfStock.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.pfStockError != null && provider.pfStock.isEmpty) {
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
                      provider.pfStockError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchPfStock(),
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

          final all = provider.pfStock;
          final query = _searchQuery.trim().toLowerCase();
          // Kategoriya guruhlari keshdan (faqat ro'yxat/qidiruv o'zgarsa).
          _rebuildGroups(all, query);
          final entries = _entries;

          return Column(
            children: [
              if (all.isNotEmpty) ...[
                _searchField(),
                _summaryLine(all.length, _emptyCount),
                _columnsHeader(),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchPfStock(),
                  child: _rowCount == 0
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 140),
                            Center(
                              child: Text(
                                all.isEmpty
                                    ? 'Полуфабрикат yo\'q'
                                    : 'Topilmadi',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            // Yassi ro'yxat: sarlavha yoki пф qatori.
                            if (entry is CategoryHeader) {
                              return CategoryHeaderTile(header: entry);
                            }
                            return _PfStockTile(row: entry as PfStockRow);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Полуфабрикат qidirish...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Qisqa xulosa: «12 ta полуфабрикат • 3 tasi tugagan».
  Widget _summaryLine(int total, int emptyCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: Row(
        children: [
          Text(
            '$total ta полуфабрикат',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (emptyCount > 0) ...[
            Text(
              ' • ',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            ),
            Text(
              '$emptyCount tasi tugagan',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _columnsHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 4),
      child: Row(
        children: [
          Expanded(child: SizedBox()),
          SizedBox(
            width: _PfStockTile.colWidth,
            child: Text('Bor',
                textAlign: TextAlign.right, style: _PfStockTile.headStyle),
          ),
          SizedBox(
            width: _PfStockTile.colWidth,
            child: Text('Band',
                textAlign: TextAlign.right, style: _PfStockTile.headStyle),
          ),
          SizedBox(
            width: _PfStockTile.colWidthWide,
            child: Text('Mumkin',
                textAlign: TextAlign.right, style: _PfStockTile.headStyle),
          ),
        ],
      ),
    );
  }
}

// Ro'yxatdagi bitta полуфабрикат qatori: rasm + nomi (+ partiya/ishlatilish)
// va o'ngda Bor / Band / Mumkin ustunlari.
class _PfStockTile extends StatelessWidget {
  final PfStockRow row;

  const _PfStockTile({required this.row});

  static const Color _accentColor = Color(0xFFC5A97B);
  static const double colWidth = 48;
  static const double colWidthWide = 58;
  static const TextStyle headStyle =
      TextStyle(fontSize: 11, color: Colors.grey);

  // Sonni chiroyli ko'rsatish: butun bo'lsa kasrsiz, aks holda 1 xona.
  static String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  static String _fullImageUrl(String url) {
    if (url.isEmpty) return '';
    return url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';
  }

  // «1 partiya = 20 dona • 3 ta mahsulotda ishlatiladi» (bo'sh bo'laklarsiz).
  String get _subtitle {
    final parts = <String>[
      if (row.batchQty > 0) '1 partiya = ${row.batchQty} dona',
      if (row.usedIn > 0) '${row.usedIn} ta mahsulotda ishlatiladi',
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final out = row.isEmptyStock;
    final imageUrl = _fullImageUrl(row.imageUrl);
    final subtitle = _subtitle;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: out ? Colors.red.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: imageUrl.isEmpty
                    ? Container(
                        color: Colors.grey.shade200,
                        child: Icon(Icons.cake_outlined,
                            color: Colors.grey.shade400),
                      )
                    : AppNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (_) => Container(
                          color: Colors.grey.shade200,
                          child: Icon(Icons.broken_image,
                              color: Colors.grey.shade400),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (out) ...[
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          row.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (row.unit.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          row.unit,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _numCell(_fmtNum(row.stock), Colors.black87, FontWeight.w600),
            _numCell(
              _fmtNum(row.reserved),
              row.reserved > 0 ? Colors.orange.shade800 : Colors.grey.shade500,
              FontWeight.w500,
            ),
            _numCell(
              _fmtNum(row.availableClamped),
              out ? Colors.red.shade700 : _accentColor,
              FontWeight.bold,
              width: colWidthWide,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numCell(String text, Color color, FontWeight weight,
      {double width = colWidth}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 14.5, color: color, fontWeight: weight),
      ),
    );
  }
}
