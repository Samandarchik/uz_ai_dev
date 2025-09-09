// ui/screens/category_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../widgets/error_retry_dialog.dart';
import 'login_page.dart';
import 'home_page.dart';

class CategoryPage extends StatefulWidget {
  final String category;
  final List<dynamic> products;

  CategoryPage({required this.category, required this.products});

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> selectedProducts = [];
  bool _isLoading = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  int _getProductQuantity(int productId) {
    int index = selectedProducts.indexWhere(
      (item) => item['product_id'] == productId,
    );
    return index != -1 ? selectedProducts[index]['count'] : 0;
  }

  void _updateQuantity(Map<String, dynamic> product, int change) {
    setState(() {
      int existingIndex = selectedProducts.indexWhere(
        (item) => item['product_id'] == product['id'],
      );

      if (existingIndex != -1) {
        int newCount = selectedProducts[existingIndex]['count'] + change;
        if (newCount <= 0) {
          selectedProducts.removeAt(existingIndex);
        } else {
          selectedProducts[existingIndex]['count'] = newCount;
        }
      } else if (change > 0) {
        selectedProducts.add({
          'product_id': product['id'],
          'name': product['name'],
          'count': 1,
        });
      }

      // FAB animatsiyasi
      if (selectedProducts.isNotEmpty && !_fabAnimationController.isCompleted) {
        _fabAnimationController.forward();
      } else if (selectedProducts.isEmpty && _fabAnimationController.isCompleted) {
        _fabAnimationController.reverse();
      }
    });
  }

  void _showOrderSummary() {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hech qanday mahsulot tanlanmagan!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_cart_checkout,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Buyurtma ro\'yxati',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Jami: ${selectedProducts.length} xil mahsulot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectedProducts.length,
                    itemBuilder: (context, index) {
                      final item = selectedProducts[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item['count']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          title: Text(
                            item['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Soni: ${item['count']} dona',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!_isLoading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Bekor qilish',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _createOrderFromDialog(dialogSetState),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Yuborilmoqda...'),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send, size: 18),
                        SizedBox(width: 6),
                        Text('Buyurtma berish'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOrderFromDialog(StateSetter dialogSetState) async {
    if (selectedProducts.isEmpty) return;

    dialogSetState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? userData = prefs.getString('user');

      if (token == null || userData == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
        return;
      }

      Map<String, dynamic> user = jsonDecode(userData);

      final orderData = {
        'username': 'Mijoz',
        'filial': user['filial']['name'],
        'items': selectedProducts
            .map((item) => {
                  'product_id': item['product_id'],
                  'count': item['count'],
                })
            .toList(),
      };

      final result = await ApiService.createOrder(token, orderData);

      if (result['success'] == true) {
        // Muvaffaqiyatli - Dialog yopish va home page ga qaytish
        Navigator.pop(context);
        
        setState(() {
          selectedProducts.clear();
        });

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Buyurtma muvaffaqiyatli yuborildi!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Xato - Dialog ochiq qolsin va error dialog ko'rsat
        dialogSetState(() {
          _isLoading = false;
        });

        _showRetryErrorDialog(result['message'] ?? 'Server xatosi yuz berdi');

        if (result['needLogin'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      }
    } catch (e) {
      // Xato - Dialog ochiq qolsin
      dialogSetState(() {
        _isLoading = false;
      });
      
      _showRetryErrorDialog('Internetga ulanishda xato: $e');
    }
  }

  void _showRetryErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorRetryDialog(
        message: message,
        onRetry: () {
          Navigator.pop(context); // Error dialog yopish
          // Buyurtma dialog ochiq qoladi, faqat retry tugmasi yana faol bo'ladi
        },
      ),
    );
  }

  Future<bool> _showExitConfirmDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Savatda mahsulotlar bor!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600),
                    SizedBox(width: 8),
                    Text(
                      'Savatda ${selectedProducts.length} xil mahsulot tanlangan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Tanlangan mahsulotlar:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Column(
                    children: selectedProducts.map((item) => Container(
                      margin: EdgeInsets.only(bottom: 4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item['count']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['name'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Nima qilmoqchisiz?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('continue'),
              child: Text(
                'Davom etish',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('order'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.green.shade50,
                foregroundColor: Colors.green.shade700,
              ),
              child: Text('Buyurtma berish'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('clear'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Savatni tozalash'),
            ),
          ],
        );
      },
    );

    switch (result) {
      case 'continue':
        return false;
      case 'order':
        _showOrderSummary();
        return false;
      case 'clear':
        setState(() {
          selectedProducts.clear();
          _fabAnimationController.reverse();
        });
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (selectedProducts.isNotEmpty) {
          return await _showExitConfirmDialog();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.category,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButton: ScaleTransition(
          scale: _fabScaleAnimation,
          child: selectedProducts.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _showOrderSummary,
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  icon: Icon(Icons.shopping_cart_checkout),
                  label: Text(
                    'Buyurtma (${selectedProducts.length})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  elevation: 8,
                )
              : null,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue, Colors.grey.shade50],
              stops: [0.0, 0.2],
            ),
          ),
          child: widget.products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Bu kategoriyada mahsulot yo\'q',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: EdgeInsets.all(16),
                  child: ListView.builder(
                    itemCount: widget.products.length,
                    itemBuilder: (context, index) {
                      final product = widget.products[index];
                      final quantity = _getProductQuantity(product['id']);
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name'] ?? 'Mahsulot nomi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Omborda: ${product['count'] ?? 0} dona',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: quantity > 0 ? Colors.red.shade50 : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: quantity > 0
                                          ? () => _updateQuantity(product, -1)
                                          : null,
                                      icon: Icon(
                                        Icons.remove,
                                        color: quantity > 0
                                            ? Colors.red.shade600
                                            : Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 50,
                                    height: 40,
                                    margin: EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: quantity > 0
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: quantity > 0
                                            ? Colors.blue.shade300
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$quantity',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: quantity > 0
                                              ? Colors.blue.shade800
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: () => _updateQuantity(product, 1),
                                      icon: Icon(
                                        Icons.add,
                                        color: Colors.green.shade600,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}