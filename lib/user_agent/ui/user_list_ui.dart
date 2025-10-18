import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/core/agent/urls.dart';
import 'package:uz_ai_dev/user_agent/provider/provider.dart';

// ============================================
// 1️⃣ ASOSIY SCREEN
// ============================================
class UserListUi extends StatefulWidget {
  const UserListUi({super.key});

  @override
  State<UserListUi> createState() => _UserListUiState();
}

class _UserListUiState extends State<UserListUi> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkUserSession();
    fetchUsers();
  }

  Future<void> _checkUserSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user');
    // Session tekshirish logikasi
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse(AppUrlsAgent.users));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          users = data['data'];
          filteredUsers = users;
          isLoading = false;
        });
      } else {
        throw Exception('Server xatosi: ${response.statusCode}');
      }
    } catch (e) {
      print('Xatolik: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _searchUsers(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      filteredUsers = users.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final filialPhone =
            user['filial']?['phone']?.toString().toLowerCase() ?? '';
        return name.contains(searchQuery) || filialPhone.contains(searchQuery);
      }).toList();
    });
  }

  Future<void> _handleLogout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Navigate to login screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Foydalanuvchilar"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SearchBar(onSearchChanged: _searchUsers),
                Expanded(
                  child: UserListView(
                    users: filteredUsers,
                    onUserTap: _handleUserTap,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleUserTap(Map<String, dynamic> user) async {
    final provider = Provider.of<ProductProviderAgent>(context, listen: false);

    if (provider.isSubmitting) return;

    // Dialog ochish
    final result = await OrderDialog.show(context);
    if (result == null) return;

    try {
      // Login qilish
      final token = await _loginUser(user['phone'] ?? '');
      if (token == null) {
        _showMessage("Token olinmadi ❌");
        return;
      }

      // Buyurtma yuborish
      await provider.submitOrder(
        token,
        result['comment'] ?? '',
        result['sentDataTime'],
      );

      _showMessage("Заказ отправлен ✅");
    } catch (e) {
      _showMessage("Xatolik: $e");
    }
  }

  Future<String?> _loginUser(String phone) async {
    final response = await http.post(
      Uri.parse(AppUrlsAgent.login),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': '54321'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['token'];
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ============================================
// 2️⃣ SEARCH BAR WIDGET
// ============================================
class SearchBar extends StatelessWidget {
  final Function(String) onSearchChanged;

  const SearchBar({
    super.key,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Qidirish (ism yoki filial telefoni)',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ============================================
// 3️⃣ USER LIST VIEW WIDGET
// ============================================
class UserListView extends StatelessWidget {
  final List<dynamic> users;
  final Function(Map<String, dynamic>) onUserTap;

  const UserListView({
    super.key,
    required this.users,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text("Hech narsa topilmadi"));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return UserCard(
          user: users[index],
          onTap: () => onUserTap(users[index]),
        );
      },
    );
  }
}

// ============================================
// 4️⃣ USER CARD WIDGET
// ============================================
class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filialPhone = user['filial']?['phone'] ?? 'Filial telefoni yo\'q';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Consumer<ProductProviderAgent>(
        builder: (context, provider, child) {
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: provider.isSubmitting ? null : onTap,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: provider.isSubmitting
                  ? const LoadingTitle()
                  : Text(user['name'] ?? 'Noma\'lum foydalanuvchi'),
              subtitle: Text('Filial telefoni: $filialPhone'),
            ),
          );
        },
      ),
    );
  }
}

// ============================================
// 5️⃣ LOADING TITLE WIDGET
// ============================================
class LoadingTitle extends StatelessWidget {
  const LoadingTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text("Buyurtma yuborilmoqda..."),
      ],
    );
  }
}

// ============================================
// 6️⃣ ORDER DIALOG
// ============================================
class OrderDialog {
  static Future<Map<String, dynamic>?> show(BuildContext context) async {
    final TextEditingController commentController = TextEditingController();
    DateTime selectedDateTime = DateTime.now();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Buyurtma ma\'lumotlari'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CommentField(controller: commentController),
                    const SizedBox(height: 20),
                    DateTimeSelector(
                      selectedDateTime: selectedDateTime,
                      onDateTimeChanged: (newDateTime) {
                        setDialogState(() {
                          selectedDateTime = newDateTime;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Bekor qilish'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'comment': commentController.text,
                      'sentDataTime': selectedDateTime,
                    });
                  },
                  child: const Text('Tasdiqlash'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================
// 7️⃣ COMMENT FIELD WIDGET
// ============================================
class CommentField extends StatelessWidget {
  final TextEditingController controller;

  const CommentField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Izoh (Comment)',
        hintText: 'Buyurtma haqida izoh yozing...',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }
}

// ============================================
// 8️⃣ DATE TIME SELECTOR WIDGET
// ============================================
class DateTimeSelector extends StatelessWidget {
  final DateTime selectedDateTime;
  final Function(DateTime) onDateTimeChanged;

  const DateTimeSelector({
    super.key,
    required this.selectedDateTime,
    required this.onDateTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Yetkazish vaqti:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(selectedDateTime),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showPicker(context),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Vaqtni o\'zgartirish'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showPicker(BuildContext context) async {
    DateTime tempDateTime = selectedDateTime;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext builder) {
        return CupertinoDateTimePickerSheet(
          initialDateTime: selectedDateTime,
          onConfirm: (DateTime newDateTime) {
            onDateTimeChanged(newDateTime);
          },
        );
      },
    );
  }
}

// ============================================
// 9️⃣ CUPERTINO DATE TIME PICKER SHEET
// ============================================
class CupertinoDateTimePickerSheet extends StatefulWidget {
  final DateTime initialDateTime;
  final Function(DateTime) onConfirm;

  const CupertinoDateTimePickerSheet({
    super.key,
    required this.initialDateTime,
    required this.onConfirm,
  });

  @override
  State<CupertinoDateTimePickerSheet> createState() =>
      _CupertinoDateTimePickerSheetState();
}

class _CupertinoDateTimePickerSheetState
    extends State<CupertinoDateTimePickerSheet> {
  late DateTime tempDateTime;

  @override
  void initState() {
    super.initState();
    tempDateTime = widget.initialDateTime;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 0),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.dateAndTime,
              initialDateTime: widget.initialDateTime,
              minimumDate: DateTime.now().subtract(const Duration(minutes: 1)),
              onDateTimeChanged: (DateTime newDateTime) {
                tempDateTime = newDateTime;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () {
              widget.onConfirm(tempDateTime);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Tayyor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
