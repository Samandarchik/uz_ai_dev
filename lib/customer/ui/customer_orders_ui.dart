import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/customer/provider/customer_provider.dart';
import 'package:intl/intl.dart';

class CustomerOrdersUi extends StatefulWidget {
  const CustomerOrdersUi({super.key});

  @override
  State<CustomerOrdersUi> createState() => _CustomerOrdersUiState();
}

class _CustomerOrdersUiState extends State<CustomerOrdersUi> {
  final Set<int> _expandedOrders = {};

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
      appBar: AppBar(
        title: const Text('Buyurtmalarim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<CustomerProvider>().loadOrders(),
          ),
        ],
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => provider.loadOrders(),
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_outlined,
                              size: 100, color: Colors.grey),
                          SizedBox(height: 20),
                          Text(
                            'Buyurtmalar yo\'q',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Birinchi buyurtmangizni bering!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadOrders(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: provider.orders.length,
                itemBuilder: (context, index) {
                  final order = provider.orders[index];
                  final isExpanded = _expandedOrders.contains(order.id);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedOrders.remove(order.id);
                        } else {
                          _expandedOrders.add(order.id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order ID va status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  order.orderID,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _statusColor(order.status)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _statusColor(order.status),
                                      ),
                                    ),
                                    child: Text(
                                      _statusText(order.status),
                                      style: TextStyle(
                                        color: _statusColor(order.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Icon(Icons.keyboard_arrow_down,
                                        color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Qisqacha (yopiq)
                          if (!isExpanded) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd.MM.yyyy')
                                      .format(order.created),
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  '${order.items.length} ta mahsulot',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ],

                          // Batafsil (ochilgan)
                          AnimatedCrossFade(
                            firstChild: Container(),
                            secondChild: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                if (order.items.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.shopping_bag,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            const Text('Mahsulotlar',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ...order.items.map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                      '• ${item.name}',
                                                      style: const TextStyle(
                                                          fontSize: 13)),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    "${item.count.toStringAsFixed(item.count == item.count.toInt() ? 0 : 1)} ${item.type}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                if (order.comment != null) ...[
                                  const SizedBox(height: 8),
                                  Text('Izoh: ${order.comment}',
                                      style: const TextStyle(
                                          fontStyle: FontStyle.italic)),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('dd.MM.yyyy HH:mm')
                                          .format(order.created),
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            crossFadeState: isExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
