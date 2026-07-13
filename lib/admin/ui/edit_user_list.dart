// ================ EDIT USER PAGE ================
// pages/edit_user_page.dart

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/user_model.dart';
import 'package:uz_ai_dev/admin/services/user_management_service.dart';
import 'package:uz_ai_dev/core/constants/roles.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';
import 'package:provider/provider.dart';

class EditUserPage extends StatefulWidget {
  final User? user;

  const EditUserPage({
    super.key,
    this.user,
  });

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  final UserManagementService _userService = UserManagementService();
  final FilialService _filialService = FilialService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _telegramGroupController;

  bool _isAdmin = false;
  int? _selectedFilialId;
  List<int> _selectedSklads = [];
  List<String> _selectedSources = [];
  String _selectedRole = AppRoles.seller;
  late List<String> _roleOptions;
  // Ombor roli uchun filiallar o'rniga ko'rsatiladigan skladlar (hozircha hardcode).
  static const Map<int, String> _skladOptions = {
    1: 'Marxabo Sklat',
    2: 'Sardor Sklat',
    3: 'Fresco Sklat',
    4: 'Personal Sklad',
  };
  // Yuk keltiruvchi roli uchun mahsulot manbalari (kategoriya o'rniga).
  static const Map<String, String> _sourceOptions = {
    'samarqand': 'Samarqand',
    'toshkent': 'Toshkent',
    'zagranitsa': 'Zagranitsa',
  };
  bool _isLoading = false;
  // true — _loadFilials post-frame'da boshlanguncha birinchi freymda
  // "filial yo'q" ko'rinib qolmasligi uchun.
  bool _isLoadingFilials = true;
  bool _obscurePassword = true;

  List<Filial> _filials = [];
  List<int> _categoryIds = [];
  String _filialError = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _passwordController = TextEditingController();
    _telegramGroupController =
        TextEditingController(text: widget.user?.telegramGroupId ?? '');
    _isAdmin = widget.user?.isAdmin ?? false;
    // filial_id 0 (filial belgilanmagan, masalan ombor/yuk keltiruvchi) -> null,
    // aks holda DropdownButton mos element topolmay crash bo'ladi.
    final fid = widget.user?.filial?.id ?? widget.user?.filialId;
    _selectedFilialId = (fid == null || fid == 0) ? null : fid;
    _selectedSklads = List.from(widget.user?.sklads ?? []);
    _selectedSources = List.from(widget.user?.sources ?? []);
    _categoryIds = widget.user?.categoryIds ?? [];

    // Rol tanlovi. Standart rollar + agar userning roli ulardan boshqa bo'lsa
    // (masalan superadmin) uni ham ro'yxatga qo'shamiz (dropdown crash bo'lmasligi uchun).
    _roleOptions = [
      AppRoles.seller,
      AppRoles.ombor,
      AppRoles.yukKeltiruvchi,
      AppRoles.bugalter,
      AppRoles.shef,
    ];
    final r = widget.user?.role ?? AppRoles.seller;
    _selectedRole = r.isEmpty ? AppRoles.seller : r;
    if (!_roleOptions.contains(_selectedRole)) {
      _roleOptions = [_selectedRole, ..._roleOptions];
    }

    // Bu ikkisi provider/setState orqali darhol notify qiladi; initState esa
    // build fazasida ishlaydi — "markNeedsBuild called during build" xatosi
    // chiqmasligi uchun keyingi freymga qoldiramiz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadFilials();
      _loadCategories();
    });
  }

  String _roleLabel(String role) {
    switch (role) {
      case AppRoles.seller:
        return 'Sotuvchi (do\'konchi)';
      case AppRoles.ombor:
        return 'Ombor';
      case AppRoles.yukKeltiruvchi:
        return 'Yuk keltiruvchi';
      case AppRoles.bugalter:
        return 'Bugalter';
      case AppRoles.shef:
        return 'Shef (ishlab chiqarish)';
      case AppRoles.superAdmin:
        return 'Superadmin';
      case AppRoles.admin:
        return 'Admin';
      default:
        return role;
    }
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rol',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: RadioGroup<String>(
            groupValue: _selectedRole,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedRole = value;
                  // Rol o'zgarsa filial/sklad tanlovi boshqa ro'yxatga o'tadi,
                  // eski qiymat mos kelmasligi mumkin — tozalaymiz.
                  _selectedFilialId = null;
                  _selectedSklads = [];
                });
              }
            },
            child: Column(
              children: [
                for (int i = 0; i < _roleOptions.length; i++)
                  RadioListTile<String>(
                    value: _roleOptions[i],
                    title: Text(_roleLabel(_roleOptions[i])),
                    activeColor: Colors.blue.shade600,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    shape: i < _roleOptions.length - 1
                        ? Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _telegramGroupController.dispose();
    super.dispose();
  }

  Future<void> _loadFilials() async {
    setState(() {
      _isLoadingFilials = true;
      _filialError = '';
    });
    try {
      final filials = await _filialService.getAllFilials();
      if (!mounted) return;
      setState(() {
        _filials = filials;
        _isLoadingFilials = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filialError = e.toString();
        _isLoadingFilials = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    if (provider.categories.isEmpty) {
      await provider.fetchCategories();
    }
  }

  // Rolga qarab filial/sklad tanlovini tekshiradi.
  // Xato bo'lsa snackbar chiqarib true qaytaradi (saqlashni to'xtatish uchun).
  bool _hasFilialSkladError() {
    String? message;
    if (_selectedRole == AppRoles.seller) {
      if (_selectedFilialId == null) {
        message = 'Выберите ветку';
      }
    } else if (_selectedRole == AppRoles.ombor ||
        _selectedRole == AppRoles.shef) {
      // Shef ham ombor kabi bitta sklad bilan ishlaydi (filial talab qilinmaydi).
      if (_selectedSklads.length != 1) {
        message = 'Выберите один склад';
      }
    } else if (_selectedRole == AppRoles.yukKeltiruvchi) {
      if (_selectedSklads.isEmpty) {
        message = 'Выберите хотя бы один склад';
      }
    }
    // bugalter: filial ham, sklad ham talab qilinmaydi.
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hasFilialSkladError()) return;

    // filial_id faqat seller uchun yuboriladi; ombor/yuk uchun null.
    final int? filialId = _selectedRole == AppRoles.seller ? _selectedFilialId : null;

    // Bugalter/shef kategoriya bilan cheklanmaydi — bo'sh ro'yxat yuboriladi,
    // rol almashtirilganda eski tanlov qolib ketmasligi uchun.
    final List<int> categoryIds =
        (_selectedRole == AppRoles.bugalter || _selectedRole == AppRoles.shef)
            ? []
            : _categoryIds;

    setState(() => _isLoading = true);

    try {
      if (widget.user != null) {
        // Mavjud foydalanuvchini yangilash - PUT /api/users/{id}
        final request = UpdateUserRequest(
          // Bo'sh qoldirilsa eski ism saqlanadi (kalit yuborilmaydi).
          name: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : null,
          phone: _phoneController.text.trim(),
          isAdmin: _isAdmin,
          role: _selectedRole,
          filialId: filialId,
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : null,
          categoryIds: categoryIds,
          sklads: _selectedSklads,
          // sources faqat yuk_keltiruvchi roli uchun yuboriladi;
          // boshqa rollarda kalit yuborilmaydi (backenddagi qiymat saqlanadi).
          sources: _selectedRole == AppRoles.yukKeltiruvchi
              ? _selectedSources
              : null,
          telegramGroupId: _telegramGroupController.text.trim(),
        );

        print('Updating user with request: ${request.toJson()}');
        await _userService.updateUser(widget.user!.id, request);
      } else {
        // Yangi foydalanuvchi yaratish - POST /api/register
        final request = CreateUserRequest(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          isAdmin: _isAdmin,
          role: _selectedRole,
          filialId: filialId,
          categoryIds: categoryIds,
          sklads: _selectedSklads,
          sources: _selectedRole == AppRoles.yukKeltiruvchi
              ? _selectedSources
              : null,
          telegramGroupId: _telegramGroupController.text.trim(),
        );

        print('Creating user with request: ${request.toJson()}');
        await _userService.createUser(request);
      }

      // Muvaffaqiyat
      if (mounted) {
        Navigator.of(context)
            .pop(true); // true qaytarish - o'zgarishlar bo'lganini bildiradi

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(widget.user != null
                    ? 'user_updated_success'
                    : 'new_user_created'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Rolga qarab sklad tanlovi:
  // - ombor / shef    → bitta sklad (radio)
  // - yuk_keltiruvchi → bir nechta sklad (checkbox)
  Widget _buildSkladSelector() {
    final bool isOmbor = _selectedRole == AppRoles.ombor ||
        _selectedRole == AppRoles.shef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOmbor ? 'Sklad' : 'Skladlar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isOmbor
              ? RadioGroup<int>(
                  groupValue:
                      _selectedSklads.isNotEmpty ? _selectedSklads.first : null,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSklads = [value];
                      });
                    }
                  },
                  child: Column(
                    children: [
                      for (final entry in _skladOptions.entries)
                        RadioListTile<int>(
                          value: entry.key,
                          title: Text(entry.value),
                          activeColor: Colors.blue.shade600,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final entry in _skladOptions.entries)
                      CheckboxListTile(
                        value: _selectedSklads.contains(entry.key),
                        title: Text(entry.value),
                        activeColor: Colors.blue.shade600,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              if (!_selectedSklads.contains(entry.key)) {
                                _selectedSklads.add(entry.key);
                              }
                            } else {
                              _selectedSklads.remove(entry.key);
                            }
                          });
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // Yuk keltiruvchi uchun "Yuk qayerdan keladi" tanlovi (kategoriya o'rniga).
  // Hech biri tanlanmasa — cheklov yo'q, hammasini ko'radi.
  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yuk qayerdan keladi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tanlanmasa hammasi ko\'rinadi',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final entry in _sourceOptions.entries)
                CheckboxListTile(
                  value: _selectedSources.contains(entry.key),
                  title: Text(entry.value),
                  activeColor: Colors.blue.shade600,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        if (!_selectedSources.contains(entry.key)) {
                          _selectedSources.add(entry.key);
                        }
                      } else {
                        _selectedSources.remove(entry.key);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilialSelector() {
    final int? dropdownValue = (_selectedFilialId != null &&
            _filials.any((f) => f.id == _selectedFilialId))
        ? _selectedFilialId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ветвь',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: (_isLoadingFilials)
              ? Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('branches_loading'),
                    ],
                  ),
                )
              : (_filialError.isNotEmpty)
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'branches_loading_error',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _loadFilials,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text('retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: dropdownValue,
                        hint: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('select_branch'),
                        ),
                        isExpanded: true,
                        menuMaxHeight: 400,
                        itemHeight: null,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.clear, color: Colors.grey),
                                  SizedBox(width: 12),
                                  Text(
                                    'Ветка не выбрана',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ..._filials.map((filial) {
                            return DropdownMenuItem<int?>(
                              value: filial.id,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      filial.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (filial.location != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        filial.location!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilialId = value;
                          });
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategoriyalar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Kategoriyalar yuklanmoqda...'),
                  ],
                ),
              ),
            ],
          );
        }

        if (provider.errorMessage != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategoriyalar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Xatolik yuz berdi',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _loadCategories,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text('Qayta urinish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategoriyalar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: provider.categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Kategoriyalar topilmadi',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: provider.categories.map((category) {
                        final isSelected = _categoryIds.contains(category.id);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _categoryIds.remove(category.id);
                              } else {
                                _categoryIds.add(category.id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _categoryIds.add(category.id);
                                      } else {
                                        _categoryIds.remove(category.id);
                                      }
                                    });
                                  },
                                  activeColor: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.blue.shade700
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.user != null
              ? 'Редактировать пользователя'
              : 'Новый пользователь',
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
              // Name Field
              Text(
                'Полное имя',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Ixtiyoriy — bo\'sh qolsa telefon raqam yoziladi',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                ),
                // Ism ixtiyoriy — telefon + parol yetarli.
              ),
              const SizedBox(height: 20),

              // Phone Field
              Text(
                'Номер телефона',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: '+998901234567',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Требуется вход в систему';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password Field
              Text(
                widget.user != null ? 'Новый пароль необязательно' : 'пароль',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: widget.user != null
                      ? 'Новая подсказка для пароля'
                      : 'Введите пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade600, width: 2),
                  ),
                ),
                validator: (value) {
                  if (widget.user == null && (value == null || value.isEmpty)) {
                    return 'Пароль требуется';
                  }
                  if (value != null && value.isNotEmpty && value.length < 2) {
                    return 'Пароль должен быть длиной не менее 2 символов.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Role Selector
              _buildRoleSelector(),
              const SizedBox(height: 20),

              // Filial (seller) yoki Sklad (ombor / yuk_keltiruvchi) selektori
              if (_selectedRole == AppRoles.seller)
                _buildFilialSelector()
              else if (_selectedRole == AppRoles.ombor ||
                  _selectedRole == AppRoles.yukKeltiruvchi ||
                  _selectedRole == AppRoles.shef)
                _buildSkladSelector(),
              const SizedBox(height: 20),

              // Telegram guruh ID (faqat ombor roli uchun, ixtiyoriy)
              if (_selectedRole == AppRoles.ombor) ...[
                Text(
                  'Telegram guruh ID',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _telegramGroupController,
                  decoration: InputDecoration(
                    hintText: '-1001234567890',
                    prefixIcon: const Icon(Icons.telegram),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 20),
              ],

              // Yuk keltiruvchi: kategoriya o'rniga manba (source) tanlovi.
              // Bugalter/shef: kategoriya so'ralmaydi.
              // Boshqa rollar: avvalgidek kategoriya tanlovi.
              if (_selectedRole == AppRoles.yukKeltiruvchi)
                _buildSourceSelector()
              else if (_selectedRole != AppRoles.bugalter &&
                  _selectedRole != AppRoles.shef)
                _buildCategorySelector(),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
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
                              widget.user != null ? Icons.update : Icons.add,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.user != null
                                  ? 'Обновить'
                                  : 'Создать пользователя',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
