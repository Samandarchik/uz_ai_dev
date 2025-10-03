import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_user_provider.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Foydalanuvchilarni yuklash
    Future.microtask(() => context.read<UserProviderAdmin>().getAllUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        actions: [
          // Statistika ko'rsatish
          Consumer<UserProviderAdmin>(
            builder: (context, provider, child) {
              return Chip(
                label: Text('Total: ${provider.totalUsers}'),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Qidiruv maydoni
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Qidirish...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (query) {
                context.read<UserProviderAdmin>().searchUsersLocally(query);
              },
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                FilterChip(
                  label: Text('Admin'),
                  selected:
                      context.watch<UserProviderAdmin>().filterIsAdmin == true,
                  onSelected: (selected) {
                    context
                        .read<UserProviderAdmin>()
                        .filterByAdminStatus(selected ? true : null);
                  },
                ),
                SizedBox(width: 8),
                FilterChip(
                  label: Text('Oddiy foydalanuvchi'),
                  selected:
                      context.watch<UserProviderAdmin>().filterIsAdmin == false,
                  onSelected: (selected) {
                    context
                        .read<UserProviderAdmin>()
                        .filterByAdminStatus(selected ? false : null);
                  },
                ),
                SizedBox(width: 8),
                ActionChip(
                  label: Text('Filterni tozalash'),
                  onPressed: () {
                    context.read<UserProviderAdmin>().clearFilters();
                  },
                ),
              ],
            ),
          ),

          // Foydalanuvchilar ro'yxati
          Expanded(
            child: Consumer<UserProviderAdmin>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(provider.error!),
                        ElevatedButton(
                          onPressed: () => provider.getAllUsers(),
                          child: Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.filteredUsers.isEmpty) {
                  return Center(child: Text('Foydalanuvchilar topilmadi'));
                }

                return ListView.builder(
                  itemCount: provider.filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = provider.filteredUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.name[0].toUpperCase()),
                        backgroundColor:
                            user.isAdmin ? Colors.red : Colors.blue,
                      ),
                      title: Text(user.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.phone),
                          if (user.filialId != null)
                            Text('Filial ID: ${user.filialId}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Admin toggle
                          IconButton(
                            icon: Icon(
                              user.isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              color: user.isAdmin ? Colors.red : Colors.grey,
                            ),
                            onPressed: () async {
                              final success =
                                  await provider.toggleAdminStatus(user.id);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Status o\'zgartirildi')),
                                );
                              }
                            },
                          ),
                          // Delete
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Tasdiqlash'),
                                  content: Text(
                                      '${user.name}ni o\'chirmoqchimisiz?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text('Удалить'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final success =
                                    await provider.deleteUser(user.id);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Foydalanuvchi o\'chirildi')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        provider.setSelectedUser(user);
                        // Navigate to detail screen
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show create user dialog
          // _showCreateUserDialog(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
