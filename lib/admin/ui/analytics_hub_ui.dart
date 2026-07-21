// admin/ui/analytics_hub_ui.dart — analitika markazi (AnalyticsHubUi):
// 4 ta kartadan iborat navigatsiya hub — ishlab chiqarish (AdminProductionUi),
// statistikasi, foyda nazorati (ProfitControlUi), foyda analitikasi (ProfitAnalyticsUi).
// Faqat navigatsiya, yangi mantiq yo'q.
import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/ui/admin_production_stats_ui.dart';
import 'package:uz_ai_dev/admin/ui/admin_production_ui.dart';
import 'package:uz_ai_dev/admin/ui/profit_analytics_ui.dart';
import 'package:uz_ai_dev/admin/ui/profit_control_ui.dart';
import 'package:uz_ai_dev/core/context_extension.dart';

// Analitika markazi — admin bosh menyusini soddalash uchun analitika va
// ishlab chiqarishga oid 4 ta ekran bitta hub'ga yig'ilgan: ishlab chiqarish,
// statistikasi, foyda nazorati, foyda analitikasi. Har karta mavjud ekranga
// o'tkazadi, yangi mantiq yo'q.

const Color _kBgColor = Color(0xFFFAF6F1);
const Color _kAccent = Color(0xFFC5A97B);

class AnalyticsHubUi extends StatelessWidget {
  const AnalyticsHubUi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: _kBgColor,
        elevation: 0,
        title: const Text(
          'Analitika',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: [
          _hubCard(
            context,
            icon: Icons.factory_outlined,
            title: 'Ishlab chiqarish',
            subtitle: 'Buyurtmalar va bosqichlar',
            page: const AdminProductionUi(),
          ),
          _hubCard(
            context,
            icon: Icons.query_stats,
            title: 'Ishlab chiqarish statistikasi',
            subtitle: 'Kunlik/oylik ishlab chiqarish',
            page: const AdminProductionStatsUi(),
          ),
          _hubCard(
            context,
            icon: Icons.price_check,
            title: 'Foyda nazorati',
            subtitle: 'Narx va marja nazorati',
            page: const ProfitControlUi(),
          ),
          _hubCard(
            context,
            icon: Icons.trending_up,
            title: 'Foyda analitikasi',
            subtitle: '30 kunlik foyda tahlili',
            page: const ProfitAnalyticsUi(),
          ),
        ],
      ),
    );
  }

  // Bitta hub kartasi: ikonka + sarlavha + bir qatorlik izoh.
  Widget _hubCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(page),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF8A6F45), size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
