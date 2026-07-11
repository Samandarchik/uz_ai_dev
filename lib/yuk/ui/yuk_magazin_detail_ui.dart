import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/yuk/models/magazin_model.dart';
import 'package:uz_ai_dev/yuk/provider/magazin_provider.dart';
import 'package:uz_ai_dev/yuk/ui/widgets/magazin_form_sheet.dart';
import 'package:uz_ai_dev/yuk/ui/widgets/yuk_day_cards.dart' show formatMoney;

// Bitta magazinning tafsiloti: tepada rasm (bosilsa to'liq ekran), do'kon
// nomi, egasi, telefon va shu magazinga JAMI qarz; ostida qarz yozuvlari
// (eng yangisi birinchi). Pastda ikkita tugma — "Qarz qo'shish" (musbat
// yozuv) va "To'lov" (avans bergandagidek summa + izoh, manfiy yozuv bo'lib
// saqlanadi, qarzni kamaytiradi). Jami manfiy bo'lsa — "Avans berilgan"
// (yashil): magazinga qarzdan ortiq pul berilgan.
// Yozuv uzoq bosilsa — tasdiq bilan o'chirish (xato kiritilgan yozuv uchun).
// AppBar: tahrirlash (o'sha forma oldindan to'ldirilgan) va o'chirish.
class YukMagazinDetailUi extends StatefulWidget {
  final Magazin magazin;
  const YukMagazinDetailUi({super.key, required this.magazin});

  @override
  State<YukMagazinDetailUi> createState() => _YukMagazinDetailUiState();
}

class _YukMagazinDetailUiState extends State<YukMagazinDetailUi> {
  static const Color _bg = Color(0xFFFAF6F1);
  static const Color _accent = Color(0xFFC5A97B);
  static const Color _red = Color(0xFFC62828);
  static const Color _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    // Ekran ochilganda qarz yozuvlarini yuklaymiz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MagazinProvider>().fetchDetail(widget.magazin);
      }
    });
  }

  // Provider'dagi xabarli Exception'ni SnackBar'da ko'rsatish.
  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
    );
  }

  // Magazinni o'chirish: tasdiq -> DELETE -> orqaga qaytish.
  Future<void> _deleteMagazin(Magazin m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.shopName),
        content: const Text(
          'Magazin va uning barcha qarz yozuvlari o\'chiriladi. '
          'Davom etilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<MagazinProvider>().deleteMagazin(m.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e);
    }
  }

  // Bitta qarz yozuvini o'chirish (uzoq bosilganda, tasdiq bilan).
  Future<void> _deleteDebt(MagazinDebt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yozuvni o\'chirish'),
        content: Text(
          '${formatMoney(debt.amount)} so\'m yozuvi o\'chirilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context
          .read<MagazinProvider>()
          .deleteDebt(widget.magazin.id, debt);
    } catch (e) {
      _showError(e);
    }
  }

  // Qarz qo'shish / to'lov bottom sheet'i: Summa (faqat raqam) + Izoh
  // (ixtiyoriy). isPayment=true — summa manfiy bo'lib yuboriladi (to'lov).
  void _showDebtSheet({required bool isPayment}) {
    final provider = context.read<MagazinProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _DebtFormSheet(
          provider: provider,
          magazinId: widget.magazin.id,
          isPayment: isPayment,
        ),
      ),
    );
  }

  // Rasmni to'liq ekranda ko'rish (boshqa ekranlardagi biriktirma
  // dialogi bilan bir xil uslub: qora fon + InteractiveViewer).
  void _openImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(magazinFullImageUrl(imageUrl)),
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
    return Consumer<MagazinProvider>(
      builder: (context, provider, _) {
        // Server javobi kelguncha ro'yxatdan kelgan magazin ko'rsatiladi.
        final m = provider.detailMagazin?.id == widget.magazin.id
            ? provider.detailMagazin!
            : widget.magazin;

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            title: Text(
              m.shopName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                onPressed: () => showMagazinFormSheet(
                  context,
                  provider,
                  magazin: m,
                ),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Tahrirlash',
              ),
              IconButton(
                onPressed: () => _deleteMagazin(m),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'O\'chirish',
              ),
            ],
          ),
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // To'lov — magazinga pul berildi (qarz kamayadi).
              FloatingActionButton.extended(
                heroTag: 'magazin_tolov_fab',
                backgroundColor: _green,
                foregroundColor: Colors.white,
                onPressed: () => _showDebtSheet(isPayment: true),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('To\'lov'),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                heroTag: 'magazin_qarz_fab',
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                onPressed: () => _showDebtSheet(isPayment: false),
                icon: const Icon(Icons.add),
                label: const Text('Qarz qo\'shish'),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: _accent,
            onRefresh: () => provider.fetchDetail(m),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 8, bottom: 90),
              children: [
                _headerCard(m),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'Qarz yozuvlari',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                if (provider.isLoadingDetail && provider.debts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                        child: CircularProgressIndicator.adaptive()),
                  )
                else if (provider.detailError != null &&
                    provider.debts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        provider.detailError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                else if (provider.debts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Hozircha qarz yozuvi yo\'q',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                else
                  for (final debt in provider.debts) _debtCard(debt),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tepadagi magazin kartasi: rasm + ma'lumotlar + jami qarz.
  Widget _headerCard(Magazin m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: m.imageUrl.isEmpty ? null : () => _openImage(m.imageUrl),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFF0E8DC),
                  backgroundImage: m.imageUrl.isNotEmpty
                      ? NetworkImage(magazinFullImageUrl(m.imageUrl))
                      : null,
                  child: m.imageUrl.isEmpty
                      ? const Icon(Icons.storefront_outlined,
                          color: _accent, size: 32)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.shopName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (m.name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        m.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    if (m.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        m.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                m.totalDebt < 0 ? 'Avans berilgan:' : 'Jami qarz:',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Text(
                '${formatMoney(m.totalDebt.abs())} so\'m',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: m.totalDebt < 0 ? _green : _red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bitta qarz yozuvi kartasi: summa (musbat — qizil qarz, manfiy — yashil
  // to'lov), izoh va sana. Uzoq bosilsa o'chirish tasdig'i.
  Widget _debtCard(MagazinDebt debt) {
    final isPayment = debt.amount < 0;
    final dateStr = debt.created == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm').format(debt.created!.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _deleteDebt(debt),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${isPayment ? '-' : '+'}'
                      '${formatMoney(debt.amount.abs())} so\'m',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isPayment ? _green : _red,
                      ),
                    ),
                  ),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                ],
              ),
              if (debt.comment.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    debt.comment,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Qarz qo'shish / to'lov formasi: Summa (faqat raqam, majburiy) + Izoh
// (ixtiyoriy). isPayment=true — to'lov rejimi: summa manfiy yozuv bo'lib
// saqlanadi (magazinga pul berildi, qarz kamayadi).
class _DebtFormSheet extends StatefulWidget {
  final MagazinProvider provider;
  final int magazinId;
  final bool isPayment;
  const _DebtFormSheet({
    required this.provider,
    required this.magazinId,
    required this.isPayment,
  });

  @override
  State<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<_DebtFormSheet> {
  static const Color _accent = Color(0xFFC5A97B);
  static const Color _green = Color(0xFF2E7D32);

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summani kiriting')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      // To'lov rejimida summa manfiy yuboriladi — qarz kamayadi.
      await widget.provider.addDebt(
        widget.magazinId,
        widget.isPayment ? -amount : amount,
        _commentCtrl.text.trim(),
      );
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isPayment ? 'To\'lov (pul berish)' : 'Qarz qo\'shish',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Summa',
                suffixText: 'so\'m',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                hintText: widget.isPayment
                    ? 'Masalan: naqd berildi'
                    : 'Masalan: un 2 qop',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isPayment ? _green : _accent,
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
                  : const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
