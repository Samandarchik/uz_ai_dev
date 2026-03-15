import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:intl/intl.dart';

class BringerPurchasedUi extends StatelessWidget {
  const BringerPurchasedUi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sotib olinganlar')),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          final order = provider.activeOrder;
          if (order == null || order.items.isEmpty) {
            return const Center(child: Text('Hali hech narsa sotib olinmagan'));
          }

          return Column(
            children: [
              // Umumiy ma'lumot
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.green.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order: ${order.orderID}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${order.items.length} ta mahsulot',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    Text(
                      '${_formatMoney(order.total)} so\'m',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              // Mahsulotlar ro'yxati
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl:
                                      "${AppUrls.baseUrl}${item.imageUrl}",
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.image),
                                )
                              : const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Icon(Icons.image)),
                        ),
                        title: Text(item.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_fmtCount(item.count)} ${item.type} x ${_formatMoney(item.price)} so\'m',
                            ),
                            Text(
                              'Jami: ${_formatMoney(item.subtotal)} so\'m',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                            ),
                            if (item.comment != null)
                              Text(item.comment!,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12)),
                            Text(
                              DateFormat('HH:mm').format(item.created),
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmtCount(double c) {
    return c == c.toInt() ? c.toInt().toString() : c.toStringAsFixed(1);
  }

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ');
  }
}
