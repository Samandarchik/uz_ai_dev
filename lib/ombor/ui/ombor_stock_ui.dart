import 'package:flutter/material.dart';
import 'package:uz_ai_dev/production/models/stock_model.dart';
import 'package:uz_ai_dev/production/ui/widgets/stock_widgets.dart';

// Ombor: o'z skladi qoldiqlari sahifasi — qidiruv, qoldiqlar ro'yxati,
// korreksiya kiritish va (qator bosilganda) harakatlar tarixi.
// Foydalanuvchiga bir nechta sklad biriktirilgan bo'lsa — tablar.
class OmborStockUi extends StatefulWidget {
  const OmborStockUi({super.key});

  @override
  State<OmborStockUi> createState() => _OmborStockUiState();
}

class _OmborStockUiState extends State<OmborStockUi> {
  static const Color _bgColor = Color(0xFFFAF6F1);
  static const Color _accentColor = Color(0xFFC5A97B);

  List<int> _sklads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSklads();
  }

  // SharedPreferences'dagi 'user' JSON ichidan skladlar ro'yxati.
  Future<void> _loadSklads() async {
    final sklads = await loadUserSklads();
    if (!mounted) return;
    setState(() {
      _sklads = sklads;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (_sklads.isEmpty) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: const Text(
            'Qoldiq',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sizga hech qanday sklad biriktirilmagan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    // Bitta sklad — tabsiz oddiy sahifa.
    if (_sklads.length == 1) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: Text(
            'Qoldiq — ${productionSkladName(_sklads.first)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body: StockSkladView(skladId: _sklads.first, canAdjust: true),
      );
    }

    // Bir nechta sklad — tablar.
    return DefaultTabController(
      length: _sklads.length,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          title: const Text(
            'Qoldiq',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            isScrollable: _sklads.length > 2,
            indicatorColor: _accentColor,
            labelColor: _accentColor,
            unselectedLabelColor: Colors.black54,
            tabs:
                _sklads.map((id) => Tab(text: productionSkladName(id))).toList(),
          ),
        ),
        body: TabBarView(
          children: _sklads
              .map((id) => StockSkladView(skladId: id, canAdjust: true))
              .toList(),
        ),
      ),
    );
  }
}
