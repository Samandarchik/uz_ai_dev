import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/media/in_app_photo_camera.dart';
import 'package:uz_ai_dev/yuk/models/magazin_model.dart';
import 'package:uz_ai_dev/yuk/provider/magazin_provider.dart';

// Magazin qo'shish/tahrirlash formasi (bottom sheet) — ro'yxat ("+" FAB)
// va tafsilot (tahrirlash tugmasi) ekranlari BIR XIL formani ishlatadi.
// Rasm: image_picker (kamera/galereya) -> avval /api/yuk/upload'ga
// yuklanadi -> qaytgan '/static/yuk/...' URL image_url sifatida yuboriladi.

// Relativ '/static/...' rasm URL'ini to'liq manzilga aylantirish
// (loyihaning boshqa ekranlaridagi _attachmentUrl bilan bir xil qoida).
String magazinFullImageUrl(String url) =>
    url.startsWith('http') ? url : '${AppUrls.baseUrl}$url';

// Formani ochish. magazin=null — yangi qo'shish, aks holda tahrirlash
// (maydonlar oldindan to'ldiriladi).
Future<void> showMagazinFormSheet(
  BuildContext context,
  MagazinProvider provider, {
  Magazin? magazin,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => Padding(
      // Klaviatura ochilganda forma ko'tarilib turishi uchun.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _MagazinFormSheet(provider: provider, magazin: magazin),
    ),
  );
}

class _MagazinFormSheet extends StatefulWidget {
  final MagazinProvider provider;
  final Magazin? magazin;
  const _MagazinFormSheet({required this.provider, this.magazin});

  @override
  State<_MagazinFormSheet> createState() => _MagazinFormSheetState();
}

class _MagazinFormSheetState extends State<_MagazinFormSheet> {
  static const Color _accent = Color(0xFFC5A97B);

  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.magazin?.name ?? '');
  late final TextEditingController _shopCtrl =
      TextEditingController(text: widget.magazin?.shopName ?? '');
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.magazin?.phone ?? '');

  final ImagePicker _picker = ImagePicker();
  // Serverda allaqachon turgan rasm (tahrirlashda) — '/static/...'.
  late String _serverImageUrl = widget.magazin?.imageUrl ?? '';
  // Endi tanlangan lokal fayl (saqlashda yuklanadi).
  String? _localImagePath;

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shopCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Kamera ilova ICHIDA ochiladi (InAppPhotoCamera) — tashqi kamera
      // ilovasi Android'da ilovani orqa fonda o'ldirilishiga sabab bo'lardi.
      final XFile? file = source == ImageSource.camera
          ? await Navigator.of(context).push<XFile>(
              MaterialPageRoute(builder: (_) => const InAppPhotoCamera()),
            )
          : await _picker.pickImage(source: source);
      if (file == null || !mounted) return;
      setState(() => _localImagePath = file.path);
    } catch (_) {
      // Ruxsat berilmagan/bekor qilingan — jim.
    }
  }

  // Kamera yoki galereya tanlash mini-sheet'i.
  void _showImageSourceSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: _accent),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _accent),
              title: const Text('Galereya'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_localImagePath != null || _serverImageUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Rasmni olib tashlash'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _localImagePath = null;
                    _serverImageUrl = '';
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final shopName = _shopCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || shopName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ismi va magazin nomini kiriting')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Avval rasm (tanlangan bo'lsa) yuklanadi, keyin magazin saqlanadi.
      var imageUrl = _serverImageUrl;
      if (_localImagePath != null) {
        imageUrl = await widget.provider.uploadImage(_localImagePath!);
      }
      if (widget.magazin == null) {
        await widget.provider.createMagazin(
          name: name,
          shopName: shopName,
          phone: phone,
          imageUrl: imageUrl,
        );
      } else {
        await widget.provider.updateMagazin(
          widget.magazin!.id,
          name: name,
          shopName: shopName,
          phone: phone,
          imageUrl: imageUrl,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.magazin != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Magazinni tahrirlash' : 'Yangi magazin',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            // Rasm tanlash (dumaloq preview + kamera belgisi).
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _showImageSourceSheet,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFFF0E8DC),
                      backgroundImage: _localImagePath != null
                          ? FileImage(File(_localImagePath!))
                          : (_serverImageUrl.isNotEmpty
                              ? NetworkImage(
                                  magazinFullImageUrl(_serverImageUrl))
                              : null) as ImageProvider?,
                      child: _localImagePath == null && _serverImageUrl.isEmpty
                          ? const Icon(Icons.storefront_outlined,
                              size: 36, color: _accent)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_camera,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ismi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Magazin nomi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon raqami',
                hintText: '+998 90 123 45 67',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }
}
