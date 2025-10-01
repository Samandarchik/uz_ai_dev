// ui/dialogs/order_summary_dialog.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../widgets/error_retry_dialog.dart';
import 'login_page.dart';

class OrderSummaryDialog extends StatefulWidget {
  final List<Map<String, dynamic>> selectedProducts;
  final Future<Map<String, dynamic>> Function(List<Map<String, dynamic>>)
      onOrderCreate;
  final VoidCallback onOrderSuccess;

  const OrderSummaryDialog({
    Key? key,
    required this.selectedProducts,
    required this.onOrderCreate,
    required this.onOrderSuccess,
  }) : super(key: key);

  @override
  _OrderSummaryDialogState createState() => _OrderSummaryDialogState();
}

class _OrderSummaryDialogState extends State<OrderSummaryDialog> {
  bool _isLoading = false;

  Future<void> _createOrder() async {
    if (widget.selectedProducts.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.onOrderCreate(widget.selectedProducts);

      if (result['success'] == true) {
        // Muvaffaqiyatli - Dialog yopish va home page ga qaytish
        Navigator.pop(context);
        widget.onOrderSuccess();
      } else {
        // Xato - Dialog ochiq qolsin va error dialog ko'rsat
        setState(() {
          _isLoading = false;
        });

        _showRetryErrorDialog(result['message'] ?? "internal_error".tr());

        if (result['needLogin'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      }
    } catch (e) {
      // Xato - Dialog ochiq qolsin
      setState(() {
        _isLoading = false;
      });

      _showRetryErrorDialog('${"internal_error"}: $e');
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            'order_list'.tr(),
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
                    '${"total".tr()}: ${widget.selectedProducts.length} ${"different_product".tr()}',
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
                itemCount: widget.selectedProducts.length,
                itemBuilder: (context, index) {
                  final item = widget.selectedProducts[index];
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
                        '${"count".tr()}: ${item['count']} ${"pieces".tr()}',
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
              'cancel'.tr(),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createOrder,
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
                    Text('sending'.tr()),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send, size: 18),
                    SizedBox(width: 6),
                    Text('ordering'.tr()),
                  ],
                ),
        ),
      ],
    );
  }
}
