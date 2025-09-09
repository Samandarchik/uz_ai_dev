// ui/screens/orders_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'login_page.dart';

class OrdersPage extends StatefulWidget {
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<dynamic> orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  _loadOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
      return;
    }

    final result = await ApiService.getOrders(token);

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        orders = result['data'] ?? [];
        _errorMessage = null;
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

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _loadOrders();
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
        return 'Chop Etildi';
      case 'preparing':
        return 'Tayyorlanmoqda';
      case 'ready':
        return 'Tayyor';
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
        title: Text(
          'Buyurtmalarim',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Buyurtmalar yuklanmoqda...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: Text('Qayta urinish'),
                      ),
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
                                    'Hali buyurtmalar yo\'q',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Birinchi buyurtmangizni bering!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
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
                          child: ListView.builder(
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 12),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      /// Buyurtma raqami va status
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Buyurtma #${order['order_id'] ?? order['id']}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                      order['status'] ??
                                                          'unknown')
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                    order['status'] ??
                                                        'unknown'),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusText(
                                                  order['status'] ?? 'unknown'),
                                              style: TextStyle(
                                                color: _getStatusColor(
                                                    order['status'] ??
                                                        'unknown'),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),

                                      /// Mijoz
                                      Row(
                                        children: [
                                          Icon(Icons.person,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 6),
                                          Text(
                                            'Mijoz: ${order['username'] ?? 'N/A'}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6),

                                      /// Filial
                                      Row(
                                        children: [
                                          Icon(Icons.location_on,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 6),
                                          Text(
                                            'Filial: ${order['filial_name'] ?? 'N/A'}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),

                                      /// Mahsulotlar ro'yxati (chek formatida)
                                      if (order['items'] != null &&
                                          order['items'].isNotEmpty) ...[
                                        SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.shopping_bag,
                                                size: 16, color: Colors.grey),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                children: List.generate(
                                                  order['items'].length,
                                                  (itemIndex) => Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          order['items'][
                                                                      itemIndex]
                                                                  ['name'] ??
                                                              'N/A',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      Text(
                                                        order['items']
                                                                    [itemIndex]
                                                                ['count']
                                                            .toString(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      SizedBox(height: 8),

                                      /// Vaqti
                                      Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 16, color: Colors.grey),
                                          SizedBox(width: 6),
                                          Text(
                                            'Vaqti: ${order['created'] != null ? DateTime.parse(order['created']).toLocal().toString().split('.')[0] : 'N/A'}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )),
                    ),
    );
  }
}
