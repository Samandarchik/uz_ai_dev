// ================ USERS SCREEN (HR uslubida) ================
// Foydalanuvchilar ro'yxati: oq karta ichida qatorlar, har qatorda avatar
// (bosh harflar), telefon, ochiq parol, Telegram holati va rol pill'i.
// Qator bosilsa — tahrirlash dialogi, uzoq bosilsa — o'chirish tasdig'i.
// Yuborish tugmalari login+parolni Telegram orqali jo'natadi.

import 'package:flutter/material.dart';
import 'package:uz_ai_dev/admin/model/user_model.dart';
import 'package:uz_ai_dev/admin/services/user_management_service.dart';
import 'package:uz_ai_dev/admin/ui/user_edit_dialog.dart';
import 'package:uz_ai_dev/core/constants/roles.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();

  List<User> _users = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final users = await _userService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _errText(e);
        _isLoading = false;
      });
    }
  }

  String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

  String _displayName(User u) => u.name.isNotEmpty ? u.name : u.phone;

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==================== Amallar ====================

  Future<void> _openEditDialog(User? user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => UserEditDialog(user: user),
    );
    if (result == true && mounted) {
      _showSnack(
        user != null
            ? 'Foydalanuvchi yangilandi'
            : 'Yangi foydalanuvchi yaratildi',
        Colors.green.shade600,
      );
      _loadUsers();
    }
  }

  Future<void> _confirmDelete(User user) async {
    final name = _displayName(user);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('O\'chirish'),
        content: Text('$name o\'chirilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Yo\'q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _userService.deleteUser(user.id);
      if (!mounted) return;
      _showSnack('Foydalanuvchi o\'chirildi', Colors.green.shade600);
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showSnack(_errText(e), Colors.red.shade600);
    }
  }

  /// Bitta foydalanuvchiga login+parolni Telegram orqali yuborish.
  Future<void> _sendCredentials(User user) async {
    final name = _displayName(user);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Telegram orqali yuborish'),
        content:
            Text('$name — login va parol Telegram orqali yuborilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Yo\'q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yuborish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    messenger.showSnackBar(const SnackBar(content: Text('Yuborilmoqda...')));
    try {
      await _userService.sendCredentials(user.id);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text('Telegram orqali yuborildi'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      // Backend xabari (masalan "Bu foydalanuvchining Telegrami bog'lanmagan").
      messenger.showSnackBar(SnackBar(
        content: Text(_errText(e)),
        backgroundColor: Colors.red,
      ));
    }
  }

  /// Barcha foydalanuvchilarga login+parolni Telegram orqali yuborish.
  Future<void> _sendAllCredentials() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hammaga yuborish'),
        content: const Text(
            'Barcha foydalanuvchilarga login va parol Telegram orqali yuborilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Yo\'q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yuborish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    messenger.showSnackBar(const SnackBar(content: Text('Yuborilmoqda...')));
    try {
      final res = await _userService.sendAllCredentials();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final parts = <String>['${res.sent} ta yuborildi'];
      if (res.skipped.isNotEmpty) {
        parts.add('${res.skipped.length} ta Telegramsiz');
      }
      if (res.failed.isNotEmpty) parts.add('${res.failed.length} ta xato');
      messenger.showSnackBar(SnackBar(
        content: Text(parts.join(' · ')),
        backgroundColor: res.failed.isNotEmpty ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 6),
        action: res.skipped.isNotEmpty
            ? SnackBarAction(
                label: 'Batafsil',
                textColor: Colors.white,
                onPressed: () => _showSkippedDialog(res.skipped),
              )
            : null,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(_errText(e)),
        backgroundColor: Colors.red,
      ));
    }
  }

  /// Telegrami bog'lanmagani uchun o'tkazib yuborilganlar ro'yxati +
  /// botga ulanish yo'riqnomasi.
  Future<void> _showSkippedDialog(List<String> skipped) async {
    final botUsername = await _userService.getTelegramBotUsername();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Telegram ulanmaganlar'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final name in skipped)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'Ular @$botUsername botiga kirib, telefon raqamini '
                    'yuborishi kerak',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  // ==================== UI bo'laklari ====================

  String _roleLabel(String role) {
    switch (role) {
      case AppRoles.seller:
        return 'Sotuvchi';
      case AppRoles.ombor:
        return 'Ombor';
      case AppRoles.yukKeltiruvchi:
        return 'Yuk keltiruvchi';
      case AppRoles.bugalter:
        return 'Bugalter';
      case AppRoles.shef:
        return 'Shef';
      case AppRoles.admin:
      case AppRoles.superAdmin:
        return 'Admin';
      default:
        return role;
    }
  }

  bool _isAdminUser(User u) =>
      u.isAdmin || u.role == AppRoles.admin || u.role == AppRoles.superAdmin;

  String _initials(User u) {
    final name = _displayName(u).trim();
    if (name.isEmpty) return '?';
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _avatar(User u, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE0E7FF),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(u),
        style: TextStyle(
          fontSize: size >= 72 ? 24 : 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3730A3),
        ),
      ),
    );
  }

  Widget _rolePill(User u) {
    final isAdmin = _isAdminUser(u);
    final bg = isAdmin ? const Color(0xFFFEF3C7) : const Color(0xFFEEF2FF);
    final border = isAdmin ? const Color(0xFFFDE68A) : const Color(0xFFC7D2FE);
    final dot = isAdmin ? const Color(0xFFD97706) : const Color(0xFF4F46E5);
    final textColor =
        isAdmin ? const Color(0xFF92400E) : const Color(0xFF3730A3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isAdmin ? 'Admin' : _roleLabel(u.role),
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneLine(User u, {double fontSize = 13}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF2563EB)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            u.phone,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2563EB),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF2563EB),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _passwordLine(User u) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.key_rounded, size: 14, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            u.passwordPlain,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Telegram bog'langan/bog'lanmagan holat chip'i.
  Widget _telegramStatus(User u) {
    final linked = u.telegramChatId != 0;
    final color =
        linked ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.send_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          linked ? 'Ulangan' : 'Ulanmagan',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _sendButton(User u) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Telegram orqali yuborish',
      icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF2563EB)),
      onPressed: () => _sendCredentials(u),
    );
  }

  // Tor (telefon) ekran qatori: tepada avatar + ism/telefon/parol/Telegram,
  // o'ngda yuborish tugmasi; pastda rol pill + filial.
  Widget _rowNarrow(User u, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEditDialog(u),
      onLongPress: () => _confirmDelete(u),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(width: 8),
                _avatar(u, 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName(u),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _phoneLine(u),
                      if (u.passwordPlain.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _passwordLine(u),
                      ],
                      const SizedBox(height: 4),
                      _telegramStatus(u),
                    ],
                  ),
                ),
                _sendButton(u),
              ],
            ),
            const SizedBox(height: 10),
            // Rol va filial — pastda alohida qatorda.
            Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: _rolePill(u),
                ),
                if (u.filial != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u.filial!.name,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Keng ekran qatori: hamma element bitta gorizontal qatorda.
  Widget _rowWide(User u, int index) {
    final catCount = u.categoryIds?.length ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEditDialog(u),
      onLongPress: () => _confirmDelete(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${index + 1}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
            SizedBox(width: 88, child: _avatar(u, 72)),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName(u),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _phoneLine(u, fontSize: 14),
                  if (u.passwordPlain.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _passwordLine(u),
                  ],
                  const SizedBox(height: 4),
                  _telegramStatus(u),
                ],
              ),
            ),
            SizedBox(
              width: 180,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _rolePill(u),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    u.filial?.name ?? '—',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$catCount ta kategoriya',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            _sendButton(u),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isNarrow) {
    return Padding(
      padding: EdgeInsets.all(isNarrow ? 12 : 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            '${_users.length} ta foydalanuvchi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () => _openEditDialog(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yangi foydalanuvchi'),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Hammaga Telegram orqali yuborish',
                onPressed: _sendAllCredentials,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadUsers,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _content(bool isNarrow) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.red.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(
          'Foydalanuvchilar yo\'q',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
        ),
      );
    }
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) =>
          isNarrow ? _rowNarrow(_users[i], i) : _rowWide(_users[i], i),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Foydalanuvchilar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Padding(
            padding: isNarrow
                ? const EdgeInsets.all(8)
                : const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _header(isNarrow),
                  const Divider(height: 1),
                  Expanded(child: _content(isNarrow)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
