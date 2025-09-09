// ui/widgets/error_retry_dialog.dart
import 'package:flutter/material.dart';
import 'dart:async';

class ErrorRetryDialog extends StatefulWidget {
  final String message;
  final VoidCallback onRetry;

  ErrorRetryDialog({required this.message, required this.onRetry});

  @override
  _ErrorRetryDialogState createState() => _ErrorRetryDialogState();
}

class _ErrorRetryDialogState extends State<ErrorRetryDialog>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _countdown = 10;
  bool _canRetry = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startCountdown();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();
  }

  void _startCountdown() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            _canRetry = true;
            timer.cancel();
            _animationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
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
                Icons.error_outline,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Xatolik yuz berdi',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
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
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buyurtma serverga yuborilmadi. Iltimos, qayta urinib ko\'ring.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_canRetry) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: (_countdown) / 10,
                        strokeWidth: 3,
                        backgroundColor: Colors.orange.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.shade600,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Qayta urinish uchun $_countdown soniya kutib turing...',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Bekor qilish',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: _canRetry ? widget.onRetry : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canRetry ? Colors.blue : Colors.grey.shade300,
                foregroundColor:
                    _canRetry ? Colors.white : Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: _canRetry ? 3 : 0,
              ),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(_canRetry),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _canRetry ? Icons.refresh : Icons.timer,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _canRetry ? 'Qayta urinish' : '$_countdown soniya',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
