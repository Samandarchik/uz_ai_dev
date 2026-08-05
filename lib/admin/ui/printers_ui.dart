// admin/ui/printers_ui.dart — printerlar registri ekrani (PrintersUi):
// har yozuvda print-server API manzili va printer raqami. Chek yuborishda
// backend kategoriya printerini shu registrdan topib, Excel faylni o'sha
// serverga yuboradi. FAB «+» qo'shadi, tap — tahrir, long-press — o'chirish.
import 'package:flutter/material.dart';

import 'package:uz_ai_dev/admin/model/print_device_model.dart';
import 'package:uz_ai_dev/admin/services/api_printer_service.dart';

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);

class PrintersUi extends StatefulWidget {
  const PrintersUi({super.key});

  @override
  State<PrintersUi> createState() => _PrintersUiState();
}

class _PrintersUiState extends State<PrintersUi> {
  final ApiPrinterService _service = ApiPrinterService();

  List<PrintDevice> _printers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final printers = await _service.getPrinters();
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  /// Qo'shish (device == null) yoki tahrirlash dialogi.
  Future<void> _showEditDialog({PrintDevice? device}) async {
    final nameController = TextEditingController(text: device?.name ?? '');
    final urlController = TextEditingController(
      text: device?.apiUrl ?? 'https://marxabo1.javohir-jasmina.uz',
    );
    final noController = TextEditingController(
      text: device == null ? '' : device.printerNo.toString(),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(device == null ? 'Printer qo\'shish' : 'Printerni tahrirlash'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nomi',
                  hintText: 'Oshxona printeri',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nomini kiriting' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API manzili',
                  hintText: 'https://marxabo1.javohir-jasmina.uz',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'API manzilini kiriting';
                  if (!t.startsWith('http://') && !t.startsWith('https://')) {
                    return 'http:// yoki https:// bilan boshlansin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Printer raqami',
                  hintText: 'Print-serverdagi raqam, masalan 4',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Musbat raqam kiriting';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kAccent),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final name = nameController.text.trim();
    final apiUrl = urlController.text.trim();
    final printerNo = int.parse(noController.text.trim());

    try {
      if (device == null) {
        await _service.addPrinter(
          name: name,
          apiUrl: apiUrl,
          printerNo: printerNo,
        );
        _showSnack('Printer qo\'shildi');
      } else {
        await _service.updatePrinter(
          device.id,
          name: name,
          apiUrl: apiUrl,
          printerNo: printerNo,
        );
        _showSnack('Printer yangilandi');
      }
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _confirmDelete(PrintDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Printerni o\'chirish'),
        content: Text(
          '"${device.name}" o\'chirilsinmi?\n\n'
          'Unga bog\'langan kategoriya bo\'lsa, backend o\'chirishga ruxsat bermaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deletePrinter(device.id);
      _showSnack('Printer o\'chirildi');
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        title: const Text('Printerlar'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kAccent,
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Qayta urinish')),
          ],
        ),
      );
    }

    if (_printers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Printer yo\'q.\n«+» bilan qo\'shing: nomi, print-server API manzili '
            'va o\'sha serverdagi printer raqami.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _printers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = _printers[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              onTap: () => _showEditDialog(device: p),
              onLongPress: () => _confirmDelete(p),
              leading: CircleAvatar(
                backgroundColor: _kAccent.withValues(alpha: 0.15),
                child: Text(
                  '${p.printerNo}',
                  style: const TextStyle(
                    color: _kAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                p.apiUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}
