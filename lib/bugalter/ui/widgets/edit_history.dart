// bugalter/ui/widgets/edit_history.dart — bugalter tahrirlari tarixi vidjetlari:
// EditHistoryTile (bitta yozuv: sana, kim, maydon, eski → yangi) va formatEditDate.
// Tahrir dialogi (bugalter_home_ui) va to'liq tarix ekrani (bugalter_edits_ui) birga ishlatadi.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uz_ai_dev/admin/model/audit_log_model.dart';

// Tahrir yozuvi rangi: eski qiymat qizil, yangisi yashil (audit jurnali
// ekrani bilan bir xil).
const Color kEditOldColor = Color(0xFFD32F2F);
const Color kEditNewColor = Color(0xFF2E7D32);

String formatEditDate(DateTime? dt) =>
    dt == null ? '—' : DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());

// Bitta tahrir yozuvi. compact=true — dialog ichidagi qisqa ko'rinish
// (mahsulot nomi va izohsiz, chunki dialog allaqachon shu mahsulot haqida).
class EditHistoryTile extends StatelessWidget {
  final AuditLogEntry entry;
  final bool compact;
  const EditHistoryTile({
    super.key,
    required this.entry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = entry.fieldLabel;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1-qator: sana + kim tahrirladi.
          Row(
            children: [
              Expanded(
                child: Text(
                  formatEditDate(entry.created),
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                entry.userName.isEmpty ? '—' : entry.userName,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          // 2-qator (faqat to'liq ko'rinishda): qaysi mahsulot.
          if (!compact && entry.entityName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.entityName,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 2),
          // 3-qator: maydon nomi va eski → yangi qiymat (server tayyorlagan
          // matn — aynan ko'rsatiladi).
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (label.isNotEmpty)
                Text(
                  '$label: ',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              Text(
                entry.oldValue.isEmpty ? '—' : entry.oldValue,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: kEditOldColor,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: kEditOldColor,
                ),
              ),
              const Text('  →  ', style: TextStyle(fontSize: 12)),
              Text(
                entry.newValue.isEmpty ? '—' : entry.newValue,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: kEditNewColor,
                ),
              ),
            ],
          ),
          // 4-qator (faqat to'liq ko'rinishda): izoh — buyurtma/sklad va
          // buyurtma jamining o'zgarishi.
          if (!compact && entry.comment.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.comment,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
