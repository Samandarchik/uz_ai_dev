import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/provider/upload_image_provider.dart';
import 'package:uz_ai_dev/bringer/models/bringer_models.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:image_picker/image_picker.dart';

class AdminBringerProfilesUi extends StatefulWidget {
  const AdminBringerProfilesUi({super.key});

  @override
  State<AdminBringerProfilesUi> createState() =>
      _AdminBringerProfilesUiState();
}

class _AdminBringerProfilesUiState extends State<AdminBringerProfilesUi> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BringerProvider>().loadProfiles();
    });
  }

  void _showAddEditDialog({BringerProfile? profile}) {
    final nameController = TextEditingController(text: profile?.name ?? '');
    final phoneController = TextEditingController(text: profile?.phone ?? '');
    final descController =
        TextEditingController(text: profile?.description ?? '');
    String? imageUrl = profile?.imageUrl;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title:
                  Text(profile == null ? 'Yangi bringer' : 'Bringerni tahrirlash'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Ism'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Tavsif'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (imageUrl != null && imageUrl!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: "${AppUrls.baseUrl}$imageUrl",
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                                source: ImageSource.gallery);
                            if (picked != null) {
                              final uploadProvider =
                                  context.read<CategoryProviderAdminUpload>();
                              final url = await uploadProvider
                                  .uploadImage(File(picked.path));
                              if (url != null) {
                                setDialogState(() {
                                  imageUrl = url;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.image, size: 16),
                          label: const Text('Rasm'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Bekor'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final provider = context.read<BringerProvider>();
                    if (profile == null) {
                      await provider.createProfile(BringerProfile(
                        id: 0,
                        name: nameController.text,
                        phone: phoneController.text,
                        description: descController.text,
                        imageUrl: imageUrl ?? '',
                        isActive: true,
                      ));
                    } else {
                      await provider.updateProfile(profile.id, {
                        'name': nameController.text,
                        'phone': phoneController.text,
                        'description': descController.text,
                        if (imageUrl != null) 'image_url': imageUrl,
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Saqlash'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bringer profillar'),
        actions: [
          IconButton(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.profiles.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.profiles.isEmpty) {
            return const Center(child: Text('Bringer profillar yo\'q'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadProfiles(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.profiles.length,
              itemBuilder: (context, index) {
                final profile = provider.profiles[index];
                return Card(
                  child: ListTile(
                    leading: ClipOval(
                      child: profile.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: "${AppUrls.baseUrl}${profile.imageUrl}",
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.person),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.person),
                            ),
                    ),
                    title: Text(profile.name),
                    subtitle: Text(
                      '${profile.phone} | ${profile.isActive ? 'Aktiv' : 'Nofaol'}',
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Tahrirlash'),
                        ),
                        const PopupMenuItem(
                          value: 'toggle',
                          child: Text('Aktiv/Nofaol'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('O\'chirish',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _showAddEditDialog(profile: profile);
                        } else if (value == 'toggle') {
                          await provider.updateProfile(
                            profile.id,
                            {'is_active': !profile.isActive},
                          );
                        } else if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('O\'chirishni tasdiqlang'),
                              content: Text('${profile.name} o\'chirilsinmi?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Yo\'q'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Ha'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.deleteProfile(profile.id);
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
