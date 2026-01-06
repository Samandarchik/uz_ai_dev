import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/user_agent/provider/provider.dart';

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

  Future<void> _logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user');
    if (userData != null) {
      // User mavjud bo‘lsa xohlaysiz ishlatish mumkin
    } else {}
  }

  @override
  void initState() {
    super.initState();
    _logout();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final response =
          await http.get(Uri.parse('http://localhost:1010/api/users'));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Foydalanuvchilar"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔍 Search input
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    onChanged: _searchUsers,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Qidirish (ism yoki filial telefoni)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // 📋 List of users
                Expanded(
                  child: filteredUsers.isEmpty
                      ? const Center(child: Text("Hech narsa topilmadi"))
                      : ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final filialPhone = user['filial']?['phone'] ??
                                'Filial telefoni yo‘q';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: Consumer<ProductProviderAgent>(
                                builder: (context, provider, child) {
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: provider.isSubmitting
                                        ? null
                                        : () async {
                                            try {
                                              // 🔐 Login qilish
                                              final response = await http.post(
                                                Uri.parse(
                                                    'http://localhost:1010/api/login'),
                                                headers: {
                                                  'Content-Type':
                                                      'application/json'
                                                },
                                                body: jsonEncode({
                                                  'phone': user['phone'] ?? '',
                                                  'password': '54321',
                                                }),
                                              );

                                              if (response.statusCode == 200) {
                                                final data =
                                                    jsonDecode(response.body);
                                                final token =
                                                    data['data']['token'];

                                                if (token == null) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "Token olinmadi ❌")),
                                                  );
                                                  return;
                                                }

                                                // 🔹 Qo‘shimcha ma’lumotlar
                                                final comment = user[
                                                        'comment'] ??
                                                    ''; // agar mavjud bo‘lsa
                                                final sentDataTime = user[
                                                        'sent_data_time'] ??
                                                    DateTime.now()
                                                        .toIso8601String(); // default hozirgi vaqt

                                                // 🔄 Token + qo‘shimcha ma’lumotlarni submitOrder ga yuborish
                                                await provider.submitOrder(
                                                    token,
                                                    comment,
                                                    sentDataTime);

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          "Заказ отправлен ✅")),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Login xatolik: ${response.statusCode}")),
                                                );
                                              }
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content:
                                                        Text("Xatolik: $e")),
                                              );
                                            }
                                          },
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),
                                      title: provider.isSubmitting
                                          ? Row(
                                              children: const [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                    "Buyurtma yuborilmoqda..."),
                                              ],
                                            )
                                          : Text(user['name'] ??
                                              'Noma’lum foydalanuvchi'),
                                      subtitle:
                                          Text('Filial telefoni: $filialPhone'),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
