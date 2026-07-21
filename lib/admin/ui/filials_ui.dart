// admin/ui/filials_ui.dart — filiallar boshqaruvi ekrani (FilialsUi):
// ApiFilialService; ro'yxatni hamma admin ko'radi, qo'shish/tahrir/o'chirish
// faqat superadmin (rol SharedPreferences 'role' dan). FAB «+» qo'shadi.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/admin/model/user_model.dart';
import 'package:uz_ai_dev/admin/services/api_filial_service.dart';
import 'package:uz_ai_dev/core/constants/roles.dart';

// Filiallar boshqaruvi. Ro'yxatni hamma admin ko'radi, lekin qo'shish/
// tahrirlash/o'chirish FAQAT superadmin uchun (backend ham requireSuperAdmin
// bilan himoyalangan). Rol SharedPreferences 'role' dan o'qiladi.
//
// Superadmin: FAB "+" -> qo'shish dialogi; qatorga tap -> tahrir; long-press ->
// tasdiq bilan o'chirish. Boshqa rollar: faqat ro'yxat (tugmalar yashirin).

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);

class FilialsUi extends StatefulWidget {
  const FilialsUi({super.key});

  @override
  State<FilialsUi> createState() => _FilialsUiState();
}

class _FilialsUiState extends State<FilialsUi> {
  final ApiFilialService _service = ApiFilialService();

  List<Filial> _filials = [];
  bool _loading = true;
  String? _error;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (mounted) {
      setState(() => _isSuperAdmin = role == AppRoles.superAdmin);
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final filials = await _service.getFilials();
      if (!mounted) return;
      setState(() {
        _filials = filials;
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

  // ───────────────────────── Dialoglar (superadmin) ─────────────────────────

  // Qo'shish (filial == null) yoki tahrirlash dialogi.
  Future<void> _showFilialDialog({Filial? filial}) async {
    final nameController = TextEditingController(text: filial?.name ?? '');
    final locationController =
        TextEditingController(text: filial?.location ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(filial == null ? 'Yangi filial' : 'Filialni tahrirlash'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
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
              const SizedBox(height: 12),
              TextFormField(
                controller: locationController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Manzil',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
    final location = locationController.text.trim();

    try {
      if (filial == null) {
        await _service.addFilial(name, location);
        _showSnack('Filial qo\'shildi');
      } else {
        await _service.updateFilial(filial.id, name, location);
        _showSnack('Filial yangilandi');
      }
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _confirmDelete(Filial filial) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Filialni o\'chirish'),
        content: Text('«${filial.name}» filialini o\'chirishga ishonchingiz '
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
      await _service.deleteFilial(filial.id);
      _showSnack('Filial o\'chirildi');
      await _load();
    } catch (e) {
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
          'Filiallar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: _isSuperAdmin
          ? FloatingActionButton(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              onPressed: () => _showFilialDialog(),
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

  // Tepadagi eslatma: mahsulot-filial bog'lash bu ekranda emas.
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
              'Mahsulotni filialga biriktirish mahsulot tahriridagi filial '
              'katakchalarida qilinadi',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _filials.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null && _filials.isEmpty) {
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

    if (_filials.isEmpty) {
      return _scrollableCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Hozircha filiallar yo\'q',
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
      itemCount: _filials.length,
      itemBuilder: (context, index) => _filialCard(_filials[index]),
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

  Widget _filialCard(Filial filial) {
    final location = filial.location?.trim() ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const Icon(Icons.store_outlined, color: Color(0xFF8A6F45)),
        title: Text(
          filial.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: location.isEmpty
            ? null
            : Text(
                location,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
        trailing: _isSuperAdmin
            ? Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500)
            : null,
        onTap: _isSuperAdmin ? () => _showFilialDialog(filial: filial) : null,
        onLongPress: _isSuperAdmin ? () => _confirmDelete(filial) : null,
      ),
    );
  }
}
