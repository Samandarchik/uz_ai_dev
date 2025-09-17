// ui/dialogs/exit_confirm_dialog.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ExitConfirmDialog extends StatelessWidget {
  final List<Map<String, dynamic>> selectedProducts;
  final VoidCallback onOrderPressed;

  const ExitConfirmDialog({
    Key? key,
    required this.selectedProducts,
    required this.onOrderPressed,
  }) : super(key: key);

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
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber,
              color: Colors.red,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'cart_has_products'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
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
            'selected_products'.tr(),
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
                children: selectedProducts
                    .map((item) => Container(
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
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('continue'),
          child: Text(
            'continue'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop('order');
            onOrderPressed();
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.green.shade50,
            foregroundColor: Colors.green.shade700,
          ),
          child: Text('place_order'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop('clear'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('clear_cart'.tr()),
        ),
      ],
    );
  }
}