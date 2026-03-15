import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/customer/models/customer_models.dart';
import 'package:uz_ai_dev/customer/provider/customer_provider.dart';
import 'package:intl/intl.dart';

class AdminCustomerOrdersUi extends StatefulWidget {
  const AdminCustomerOrdersUi({super.key});

  @override
  State<AdminCustomerOrdersUi> createState() => _AdminCustomerOrdersUiState();
}

class _AdminCustomerOrdersUiState extends State<AdminCustomerOrdersUi> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadOrders();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ordered':
        return Colors.orange;
      case 'purchased':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showStatusDialog(CustomerOrder order) {
    final statuses = ['ordered', 'purchased', 'shipped', 'delivered'];
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Statusni o\'zgartirish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map((status) {
              final isSelected = order.status == status;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _statusColor(status),
                ),
                title: Text(_statusText(status)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context
                      .read<CustomerProvider>()
                      .updateOrderStatus(order.id, status);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'ordered':
        return 'Buyurtma qilingan';
      case 'purchased':
        return 'Sotib olingan';
      case 'shipped':
        return 'Yetkazilmoqda';
      case 'delivered':
        return 'Yetkazildi';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mijoz buyurtmalari')),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.orders.isEmpty) {
            return const Center(child: Text('Buyurtmalar yo\'q'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.orders.length,
              itemBuilder: (context, index) {
                final order = provider.orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    title: Text(
                      order.orderID,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showStatusDialog(order),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(order.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: _statusColor(order.status)),
                            ),
                            child: Text(
                              order.statusText,
                              style: TextStyle(
                                color: _statusColor(order.status),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd.MM.yyyy HH:mm').format(order.created),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    children: [
                      ...order.items.map((item) {
                        return ListTile(
                          dense: true,
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.count.toStringAsFixed(item.count == item.count.toInt() ? 0 : 1)} ${item.type}',
                          ),
                        );
                      }),
                      if (order.comment != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Izoh: ${order.comment}',
                              style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
