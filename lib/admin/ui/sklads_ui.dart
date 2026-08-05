// admin/ui/sklads_ui.dart — skladlar (omborxonalar) boshqaruvi ekrani
// (SkladsUi): ApiSkladService; ro'yxatni hamma ko'radi, qo'shish/tahrir/
// o'chirish ADMIN uchun (SharedPreferences 'is_admin'; backend ham
// requireAdmin — alohida superadmin foydalanuvchi amalda yo'q). FAB «+»
// qo'shadi, qatorga tap — nomni tahrirlash, long-press — o'chirish.
// Har muvaffaqiyatli amaldan keyin SkladRegistry yangilanadi, ya'ni butun
// ilovadagi sklad nomlari (tab, dropdown, kartalar) darhol yangi nomni oladi.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/admin/services/api_sklad_service.dart';
import 'package:uz_ai_dev/core/constants/roles.dart';
import 'package:uz_ai_dev/core/data/sklad_registry.dart';
import 'package:uz_ai_dev/core/models/sklad_model.dart';

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);

class SkladsUi extends StatefulWidget {
  const SkladsUi({super.key});

  @override
  State<SkladsUi> createState() => _SkladsUiState();
}

class _SkladsUiState extends State<SkladsUi> {
  final ApiSkladService _service = ApiSkladService();

  List<Sklad> _sklads = [];
  bool _loading = true;
  String? _error;
  // Tahrir tugmalari ko'rinadimi — admin (is_admin) bo'lsa. Backend ham
  // requireAdmin bilan himoyalangan.
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final isAdmin = prefs.getBool('is_admin') ?? false;
    final role = prefs.getString('role');
    if (mounted) {
      setState(() => _canEdit =
          isAdmin || role == AppRoles.admin || role == AppRoles.superAdmin);
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sklads = await _service.getSklads();
      // Ro'yxat yangilanishi bilan butun ilovadagi nomlar ham yangilanadi.
      await SkladRegistry.update(sklads);
      if (!mounted) return;
      setState(() {
        _sklads = sklads;
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

  void _showSnack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // ─────────────────────────── Dialoglar (admin) ───────────────────────────

  // Qo'shish (sklad == null) yoki nomni tahrirlash dialogi.
  Future<void> _showSkladDialog({Sklad? sklad}) async {
    final nameController = TextEditingController(text: sklad?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(sklad == null ? 'Yangi sklad' : 'Sklad nomini tahrirlash'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nomi *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nomini kiriting' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final name = nameController.text.trim();

    try {
      if (sklad == null) {
        await _service.addSklad(name);
        _showSnack('Sklad qo\'shildi');
      } else {
        await _service.updateSklad(sklad.id, name);
        _showSnack('Sklad nomi yangilandi');
      }
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _confirmDelete(Sklad sklad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skladni o\'chirish'),
        content: Text('«${sklad.name}» skladini o\'chirishga ishonchingiz '
            'komilmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _service.deleteSklad(sklad.id);
      _showSnack('Sklad o\'chirildi');
      await _load();
    } catch (e) {
      // Server sababni aytadi: foydalanuvchi/mahsulot biriktirilgan, qoldiq bor...
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        title: const Text(
          'Skladlar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              onPressed: () => _showSkladDialog(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          _hint(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: _kAccent,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF8A6F45)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _canEdit
                  ? 'Tap — nomni tahrirlash, uzoq bosish — o\'chirish. '
                      'Foydalanuvchi/mahsulot biriktirilgan yoki qoldig\'i bor '
                      'sklad o\'chmaydi'
                  : 'Skladlarni faqat admin tahrirlaydi',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _sklads.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null && _sklads.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }

    if (_sklads.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warehouse_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Hozircha skladlar yo\'q',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _sklads.length,
      itemBuilder: (context, index) => _skladCard(_sklads[index]),
    );
  }

  // Pull-to-refresh xato/bo'sh holatda ham ishlashi uchun skrollanadigan markaz.
  Widget _scrollableCenter({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _skladCard(Sklad sklad) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const Icon(Icons.warehouse_outlined, color: Color(0xFF8A6F45)),
        title: Text(
          sklad.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'ID: ${sklad.id}',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        trailing: _canEdit
            ? Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500)
            : null,
        onTap: _canEdit ? () => _showSkladDialog(sklad: sklad) : null,
        onLongPress: _canEdit ? () => _confirmDelete(sklad) : null,
      ),
    );
  }
}
