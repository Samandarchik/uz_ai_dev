// ================ EDIT USER PAGE ================
// pages/edit_user_page.dart

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin_agent/model/user_model.dart';
import 'package:uz_ai_dev/admin_agent/services/user_management_service.dart';
import 'package:uz_ai_dev/admin_agent/widgets/password_widget.dart';
import 'package:uz_ai_dev/admin_agent/widgets/save_button.dart';
import 'package:uz_ai_dev/admin_agent/widgets/text_filent.dart';

class EditUserPage extends StatefulWidget {
  final User? user;

  const EditUserPage({super.key, this.user});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  final UserManagementService _userService = UserManagementService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _longController;
  late TextEditingController _latController;
  late TextEditingController _locationController;

  bool _isAdmin = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _longController = TextEditingController(text: widget.user?.long.toString() ?? '');
    _latController = TextEditingController(text: widget.user?.lat.toString() ?? '');
    _locationController = TextEditingController(text: widget.user?.location?? '');
    _passwordController = TextEditingController();
    _isAdmin = widget.user?.isAdmin ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _longController.dispose();
    _latController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.user != null) {
        final request = UpdateUserRequest(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          isAdmin: _isAdmin,
          
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : null,
        );

        print('Updating user with request: ${request.toJson()}');
        await _userService.updateUser(widget.user!.id, request);
      } else {
        final request = CreateUserRequest(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          isAdmin: _isAdmin,
          long:  double.parse(_longController.text) ,
          lat:  double.parse(_latController.text),
          location: _locationController.text
        );

        print('Creating user with request: ${request.toJson()}');
        await _userService.createUser(request);
      }

      if (mounted) {
        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  widget.user != null
                      ? 'user_updated_success'
                      : 'new_user_created',
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error in _saveUser: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.user != null ? widget.user?.name ?? "" : 'new_user',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Name Field
              CustomTextField(
                label: 'Полное имя',
                hint: 'enter_Полное имя',
                icon: Icons.person_outline,
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Полное имя_required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Phone Field
              CustomTextField(
                label: 'Login',
                hint: '+998901234567',
                icon: Icons.phone_outlined,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'phone_number_required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password Field
              PasswordTextField(
                label: widget.user != null
                    ? 'Новый пароль необязательно'
                    : 'пароль',
                hint: widget.user != null
                    ? 'Новая подсказка для пароля'
                    : 'Введите пароль',
                controller: _passwordController,
                obscurePassword: _obscurePassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                validator: (value) {
                  if (widget.user == null && (value == null || value.isEmpty)) {
                    return 'password_required';
                  }
                  if (value != null && value.isNotEmpty && value.length < 2) {
                    return 'Parol kamida 2 ta belgidan iborat bo\'lishi kerak';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Save Button
              SaveButton(
                isLoading: _isLoading,
                isEditMode: widget.user != null,
                onPressed: _saveUser,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
