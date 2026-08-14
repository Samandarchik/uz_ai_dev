// admin/ui/widgets/rk7_common.dart — RK7 ekranlari uchun umumiy UI qismlari:
// ranglar (kRk7Bg/kRk7Accent), sana formati, xato/bo'sh holat va snackbar.
// Uch tab (import/mapping/nuqtalar) bir xil ko'rinishda bo'lishi uchun.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color kRk7Bg = Color(0xFFFAF6F1);
const Color kRk7Accent = Color(0xFFC5A97B);
const Color kRk7AccentDark = Color(0xFF8A6F45);

/// "YYYY-MM-DD" → "dd.MM.yyyy" (o'qib bo'lmasa xom holida).
String rk7Date(String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null ? date : DateFormat('dd.MM.yyyy').format(parsed);
}

/// Pull-to-refresh xato/bo'sh holatda ham ishlashi uchun skrollanadigan markaz.
Widget rk7ScrollableCenter({required Widget child}) {
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

/// Xato holati + «Qayta urinish» tugmasi.
Widget rk7ErrorState(String message, {required VoidCallback onRetry}) {
  return rk7ScrollableCenter(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: kRk7Accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Qayta urinish'),
        ),
      ],
    ),
  );
}

/// Bo'sh ro'yxat holati.
Widget rk7EmptyState(IconData icon, String message) {
  return rk7ScrollableCenter(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    ),
  );
}

/// Muvaffaqiyat/xato xabari (loyihadagi naqsh).
void rk7Snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ),
  );
}

/// Kichik rangli badge (masalan «unmapped: 3» — qizil).
Widget rk7Badge(String text, {required Color color}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}
