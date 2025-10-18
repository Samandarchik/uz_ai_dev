import 'package:flutter/material.dart';

// ================ SAVE BUTTON WIDGET ================
class SaveButton extends StatelessWidget {
  final bool isLoading;
  final bool isEditMode;
  final VoidCallback onPressed;

  const SaveButton({
    super.key,
    required this.isLoading,
    required this.isEditMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEditMode ? Icons.update : Icons.add,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditMode ? 'Обновить' : 'Создать пользователя',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
