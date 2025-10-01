// ui/screens/category_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/user/ui/screens/exit_confirm_dialog.dart';
import 'package:uz_ai_dev/user/ui/screens/order_summary_dialog.dart';
import 'dart:convert';
import '../../services/api_service.dart';

import 'home_page.dart';

// Number formatter class
class NumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    String digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }

    // Add commas every 3 digits
    String formatted = _addCommas(digits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _addCommas(String value) {
    if (value.length <= 3) return value;

    String result = '';
    int counter = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      if (counter == 3) {
        result = ',$result';
        counter = 0;
      }
      result = value[i] + result;
      counter++;
    }

    return result;
  }
}

class CategoryPage extends StatefulWidget {
  final String category;
  final List<dynamic> products;

  const CategoryPage(
      {super.key, required this.category, required this.products});

  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> selectedProducts = [];
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

  void _showQuantityInputDialog(Map<String, dynamic> product) {
    final TextEditingController controller = TextEditingController();
    final int currentQuantity = _getProductQuantity(product['id']);

    if (currentQuantity > 0) {
      // Format the current quantity with commas
      String formattedQuantity = _formatNumber(currentQuantity.toString());
      controller.text = formattedQuantity;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Miqdorni kiriting',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['name'] ?? 'Mahsulot',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              inputFormatters: [NumberTextInputFormatter()],
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Miqdori',
                hintText: 'Miqdorni kiriting',
                suffix: Text(product['type'] ?? "null"),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Omborda: ${_formatNumber((product['count'] ?? 0).toString())} ${product['type'] ?? "dona"}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Bekor qilish',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final String inputText = controller.text.trim();
              if (inputText.isNotEmpty) {
                // Remove commas and parse
                String cleanText = inputText.replaceAll(',', '');
                final int? newCount = int.tryParse(cleanText);
                if (newCount != null && newCount >= 0) {
                  _setQuantityDirectly(product, newCount);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Iltimos, to\'g\'ri raqam kiriting!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } else {
                _setQuantityDirectly(product, 0);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(String value) {
    if (value.isEmpty || value == '0') return value;

    String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';

    if (digits.length <= 3) return digits;

    String result = '';
    int counter = 0;

    for (int i = digits.length - 1; i >= 0; i--) {
      if (counter == 3) {
        result = ',$result';
        counter = 0;
      }
      result = digits[i] + result;
      counter++;
    }

    return result;
  }

  void _setQuantityDirectly(Map<String, dynamic> product, int newCount) {
    setState(() {
      int existingIndex = selectedProducts.indexWhere(
        (item) => item['product_id'] == product['id'],
      );

      if (newCount <= 0) {
        if (existingIndex != -1) {
          selectedProducts.removeAt(existingIndex);
        }
      } else {
        if (existingIndex != -1) {
          selectedProducts[existingIndex]['count'] = newCount;
        } else {
          selectedProducts.add({
            'product_id': product['id'],
            'name': product['name'],
            'count': newCount,
          });
        }
      }

      // FAB animatsiyasi
      if (selectedProducts.isNotEmpty && !_fabAnimationController.isCompleted) {
        _fabAnimationController.forward();
      } else if (selectedProducts.isEmpty &&
          _fabAnimationController.isCompleted) {
        _fabAnimationController.reverse();
      }
    });
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
      } else if (selectedProducts.isEmpty &&
          _fabAnimationController.isCompleted) {
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
      builder: (context) => OrderSummaryDialog(
        selectedProducts: selectedProducts,
        onOrderCreate: _createOrder,
        onOrderSuccess: _onOrderSuccess,
      ),
    );
  }

  Future<Map<String, dynamic>> _createOrder(
      List<Map<String, dynamic>> products) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? userData = prefs.getString('user');

      if (token == null || userData == null) {
        return {'success': false, 'needLogin': true};
      }

      Map<String, dynamic> user = jsonDecode(userData);

      final orderData = {
        'username': 'Mijoz',
        'filial': user['filial']['name'],
        'items': products
            .map((item) => {
                  'product_id': item['product_id'],
                  'count': item['count'],
                })
            .toList(),
      };

      return await ApiService.createOrder(token, orderData);
    } catch (e) {
      return {
        'success': false,
        'message': 'Internetga ulanishda xato: $e',
      };
    }
  }

  void _onOrderSuccess() {
    setState(() {
      selectedProducts.clear();
      _fabAnimationController.reverse();
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
  }

  Future<bool> _showExitConfirmDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExitConfirmDialog(
        selectedProducts: selectedProducts,
        onOrderPressed: _showOrderSummary,
      ),
    );

    switch (result) {
      case 'continue':
        return false;
      case 'order':
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
                        padding: EdgeInsets.all(10),
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
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: 120),
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
                        child: GestureDetector(
                          onTap: () => _showQuantityInputDialog(product),
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${product['name'] ?? 'Mahsulot nomi'} (${product['type'] ?? 'null'})",
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
                                            'Omborda: ${_formatNumber((product['count'] ?? 0).toString())} ${product['type'] ?? 'dona'}',
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
                                      width: 35,
                                      decoration: BoxDecoration(
                                        color: quantity > 0
                                            ? Colors.red.shade50
                                            : Colors.grey.shade100,
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
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 50,
                                      height: 40,
                                      margin:
                                          EdgeInsets.symmetric(horizontal: 8),
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
                                      child: InkWell(
                                        onTap: () =>
                                            _showQuantityInputDialog(product),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Center(
                                          child: Text(
                                            _formatNumber(quantity.toString()),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: quantity > 0
                                                  ? Colors.blue.shade800
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 35,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        onPressed: () =>
                                            _updateQuantity(product, 1),
                                        icon: Icon(Icons.add,
                                            color: Colors.green.shade600,
                                            size: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
