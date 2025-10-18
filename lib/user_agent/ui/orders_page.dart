// ui/screens/orders_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/login_page.dart';
import 'package:uz_ai_dev/user_agent/services/api_service.dart';

class OrdersPage extends StatefulWidget {
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<dynamic> orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  Set<String> _expandedOrders = Set<String>();

  // Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  int _limit = 30;
  bool _hasMore = true;

  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener - oxirga yetganda yana yuklash
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreOrders();
      }
    }
  }

  _loadOrders({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        orders.clear();
        _expandedOrders.clear();
      });
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
      return;
    }

    final result = await ApiServiceAgent.getOrders(
      token,
      page: _currentPage,
      limit: _limit,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        if (isRefresh) {
          orders = result['data'] ?? [];
        } else {
          orders.addAll(result['data'] ?? []);
        }

        _errorMessage = null;
        _currentPage = result['current_page'] ?? 1;
        _totalPages = result['last_page'] ?? 1;
        _hasMore = _currentPage < _totalPages;
      });
    } else {
      if (result['needLogin'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    }
  }

  // Qo'shimcha buyurtmalar yuklash
  _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      setState(() {
        _isLoadingMore = false;
      });
      return;
    }

    final result = await ApiServiceAgent.getOrders(
      token,
      page: _currentPage + 1,
      limit: _limit,
    );

    setState(() {
      _isLoadingMore = false;
    });

    if (result['success'] == true) {
      setState(() {
        orders.addAll(result['data'] ?? []);
        _currentPage = result['current_page'] ?? _currentPage + 1;
        _totalPages = result['last_page'] ?? 1;
        _hasMore = _currentPage < _totalPages;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _loadOrders(isRefresh: true);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sent_to_printer':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'sent_to_printer':
        return 'status_sent_to_printer';
      case 'preparing':
        return 'status_preparing';
      case 'ready':
        return 'status_ready';
      case 'delivered':
        return 'status_delivered';
      default:
        return status;
    }
  }

  void _toggleOrderExpansion(String orderId) {
    setState(() {
      if (_expandedOrders.contains(orderId)) {
        _expandedOrders.remove(orderId);
      } else {
        _expandedOrders.add(orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Мои заказы', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('loading_orders'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(onPressed: _refresh, child: Text('retry')),
                    ],
                  ),
                )
              : orders.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        children: [
                          Container(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    size: 100,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Заказов пока нет',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Сделайте первый заказ!',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Pagination info
                            if (_totalPages > 1)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.blue[700],
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'page_info'
                                          .replaceAll(
                                              '{current}', '$_currentPage')
                                          .replaceAll('{total}', '$_totalPages')
                                          .replaceAll(
                                              '{count}', '${orders.length}'),
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Orders list
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount:
                                    orders.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Loading indicator at the end
                                  if (index >= orders.length) {
                                    return Container(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            CircularProgressIndicator(
                                                strokeWidth: 2),
                                            SizedBox(height: 8),
                                            Text(
                                              'loading_more',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final order = orders[index];
                                  final orderId =
                                      order['order_id'] ?? order['id'] ?? index;
                                  final isExpanded =
                                      _expandedOrders.contains(orderId);

                                  return InkWell(
                                    onTap: () => _toggleOrderExpansion(orderId),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          /// Buyurtma raqami va status (har doim ko'rinadigan qism)
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Номер заказа: ${order['order_id'] ?? order['id']})',
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
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(
                                                        order['status'] ??
                                                            'unknown',
                                                      ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                        color: _getStatusColor(
                                                          order['status'] ??
                                                              'unknown',
                                                        ),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      _getStatusText(
                                                        order['status'] ??
                                                            'unknown',
                                                      ),
                                                      style: TextStyle(
                                                        color: _getStatusColor(
                                                          order['status'] ??
                                                              'unknown',
                                                        ),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  AnimatedRotation(
                                                    turns: isExpanded ? 0.5 : 0,
                                                    duration: Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    child: Icon(
                                                      Icons.keyboard_arrow_down,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          /// Qisqacha ma'lumot (yopiq holatda)
                                          if (!isExpanded) ...[
                                            SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${order['created'] != null ? DateTime.parse(order['created']).toLocal().toString().split(' ')[0] : 'N/A'}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Spacer(),
                                                if (order['items'] != null &&
                                                    order['items'].isNotEmpty)
                                                  Text(
                                                    'products_count'.replaceAll(
                                                      '{count}',
                                                      '${order['items'].length}',
                                                    ),
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],

                                          /// Batafsil ma'lumot (ochilgan holatda)
                                          AnimatedCrossFade(
                                            firstChild: Container(),
                                            secondChild: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(height: 12),

                                                /// Mijoz

                                                /// Mahsulotlar ro'yxati
                                                if (order['items'] != null &&
                                                    order['items']
                                                        .isNotEmpty) ...[
                                                  Container(
                                                    padding: EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey[200]!,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .shopping_bag,
                                                              size: 16,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            SizedBox(width: 6),
                                                            Text(
                                                              'products',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 8),
                                                        ...List.generate(
                                                          order['items'].length,
                                                          (itemIndex) =>
                                                              Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                              bottom: 4,
                                                            ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    '• ${order['items'][itemIndex]['name'] ?? 'N/A'}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Container(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 2,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .blue[50],
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(
                                                                      12,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'count_unit'
                                                                        .replaceAll(
                                                                      '{count}',
                                                                      '${order['items'][itemIndex]['count']}',
                                                                    ),
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: Colors
                                                                              .blue[
                                                                          700],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],

                                                SizedBox(height: 12),

                                                /// To'liq vaqt ma'lumoti
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 16,
                                                      color: Colors.grey,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'order_time',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 22),
                                                  child: Text(
                                                    '${order['created'] != null ? DateTime.parse(order['created']).toLocal().toString().split('.')[0] : 'N/A'}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            crossFadeState: isExpanded
                                                ? CrossFadeState.showSecond
                                                : CrossFadeState.showFirst,
                                            duration:
                                                Duration(milliseconds: 300),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
