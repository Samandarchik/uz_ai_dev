import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/bringer/models/bringer_models.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:intl/intl.dart';

class BringerOrdersUi extends StatefulWidget {
  final int bringerProfileId;

  const BringerOrdersUi({super.key, required this.bringerProfileId});

  @override
  State<BringerOrdersUi> createState() => _BringerOrdersUiState();
}

class _BringerOrdersUiState extends State<BringerOrdersUi> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BringerProvider>().loadOrders();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.blue;
      case 'shipped':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'active':
        return 'Aktiv';
      case 'shipped':
        return 'Yuborilgan';
      case 'delivered':
        return 'Tasdiqlangan';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xaridlar tarixi')),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.orders.isEmpty) {
            return const Center(child: Text('Xaridlar yo\'q'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.orders.length,
              itemBuilder: (context, index) {
                final order = provider.orders[index];
                return _OrderCard(
                  order: order,
                  statusColor: _statusColor(order.status),
                  statusText: _statusText(order.status),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final BringerOrder order;
  final Color statusColor;
  final String statusText;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          order.orderID,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatMoney(order.total)} so\'m',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd.MM.yyyy').format(order.created),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        children: [
          ...order.items.map((item) {
            return ListTile(
              dense: true,
              title: Text(item.name),
              subtitle: Text(
                '${item.count.toStringAsFixed(item.count == item.count.toInt() ? 0 : 1)} ${item.type} x ${_formatMoney(item.price)} = ${_formatMoney(item.subtotal)} so\'m',
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ');
  }
}
