// // ================ EDIT USER DIALOG ================
// // widgets/edit_user_dialog.dart
// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:uz_ai_dev/admin/model/product_model.dart';
// import 'package:uz_ai_dev/admin/services/category_service.dart';
// import 'package:uz_ai_dev/admin/services/filial_service.dart';
// import 'package:uz_ai_dev/admin/user_management_service.dart';
// import 'package:uz_ai_dev/user/models/user_model.dart';

// class EditUserDialog extends StatefulWidget {
//   final User? user;
//   final VoidCallback onUserSaved;

//   const EditUserDialog({
//     super.key,
//     this.user,
//     required this.onUserSaved,
//   });

//   @override
//   State<EditUserDialog> createState() => _EditUserDialogState();
// }

// class _EditUserDialogState extends State<EditUserDialog> {
//   final _formKey = GlobalKey<FormState>();
//   final UserManagementService _userService = UserManagementService();
//   final FilialService _filialService = FilialService();
//   final CategoryService _categoryService = CategoryService();

//   late TextEditingController _nameController;
//   late TextEditingController _phoneController;
//   late TextEditingController _passwordController;

//   int? _selectedFilialId;
//   List<int> _selectedCategoryIds = []; // Multiple selection uchun list
//   bool _isLoading = false;
//   bool _isLoadingFilials = false;
//   bool _isLoadingCategories = false;
//   bool _obscurePassword = true;

//   List<Filial> _filials = [];
//   List<CategoryProductAdmin> _categories = [];
//   String _filialError = '';
//   String _categoryError = '';

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController(text: widget.user?.name ?? '');
//     _phoneController = TextEditingController(text: widget.user?.phone ?? '');
//     _passwordController = TextEditingController();
//     _selectedFilialId = widget.user?.filialId;
//     // Agar user mavjud bo'lsa va categorylari bo'lsa, ularni initialize qilish
//     _selectedCategoryIds = widget.user?.categoryIds ?? [];
//     _loadFilials();
//     _loadCategories();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _phoneController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadCategories() async {
//     setState(() {
//       _isLoadingCategories = true;
//       _categoryError = '';
//     });

//     try {
//       final categories = await _categoryService.getAllCategorys();
//       setState(() {
//         _categories = categories;
//         _isLoadingCategories = false;
//       });
//     } catch (e) {
//       setState(() {
//         _categoryError = e.toString();
//         _isLoadingCategories = false;
//       });
//     }
//   }

//   Future<void> _loadFilials() async {
//     setState(() {
//       _isLoadingFilials = true;
//       _filialError = '';
//     });

//     try {
//       final filials = await _filialService.getAllFilials();
//       setState(() {
//         _filials = filials;
//         _isLoadingFilials = false;
//       });
//     } catch (e) {
//       setState(() {
//         _filialError = e.toString();
//         _isLoadingFilials = false;
//       });
//     }
//   }

//   String _formatPhoneForRequest(String phone) {
//     // +998 prefixi bor bo'lsa olib tashlash
//     String cleanPhone = phone.replaceAll('+998', '').trim();
//     // +998 prefixi qo'shish
//     return '+998$cleanPhone';
//   }

//   Future<void> _saveUser() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);

//     try {
//       if (widget.user != null) {
//         // Mavjud foydalanuvchini yangilash - PUT /api/users/{id}
//         final request = UpdateUserRequest(
//           name: _nameController.text.trim(),
//           phone: _formatPhoneForRequest(_phoneController.text.trim()),
//           filialId: _selectedFilialId,
//           categoryIds: _selectedCategoryIds, // Category IDs qo'shildi
//           password: _passwordController.text.isNotEmpty
//               ? _passwordController.text
//               : null,
//         );

//         print('Updating user with request: ${request.toJson()}'); // Debug log
//         await _userService.updateUser(widget.user!.id, request);
//       } else {
//         // Yangi foydalanuvchi yaratish - POST /api/register
//         final request = CreateUserRequest(
//           name: _nameController.text.trim(),
//           phone: _formatPhoneForRequest(_phoneController.text.trim()),
//           password: _passwordController.text,
//           filialId: _selectedFilialId!.toInt(),
//           categoryIds: _selectedCategoryIds, // Category IDs qo'shildi
//         );

//         print('Creating user with request: ${request.toJson()}'); // Debug log
//         await _userService.createUser(request);
//       }

//       // Muvaffaqiyat
//       widget.onUserSaved();
//       if (mounted) {
//         Navigator.of(context).pop();

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 const Icon(Icons.check_circle, color: Colors.white),
//                 const SizedBox(width: 12),
//                 Text(widget.user != null
//                     ? 'user_updated_success'.tr()
//                     : 'new_user_created'.tr()),
//               ],
//             ),
//             backgroundColor: Colors.green.shade600,
//             behavior: SnackBarBehavior.floating,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error in _saveUser: $e'); // Debug log

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 const Icon(Icons.error_outline, color: Colors.white),
//                 const SizedBox(width: 12),
//                 Expanded(child: Text(e.toString())),
//               ],
//             ),
//             backgroundColor: Colors.red.shade600,
//             behavior: SnackBarBehavior.floating,
//             shape:
//                 RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Widget _buildFilialSelector() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'branch'.tr(),
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Container(
//           width: double.infinity,
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: _isLoadingFilials
//               ? Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Row(
//                     children: [
//                       SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       ),
//                       SizedBox(width: 12),
//                       Text('branches_loading'.tr()),
//                     ],
//                   ),
//                 )
//               : _filialError.isNotEmpty
//                   ? Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.error_outline,
//                                   color: Colors.red.shade600, size: 20),
//                               const SizedBox(width: 8),
//                               Text(
//                                 'branches_loading_error'.tr(),
//                                 style: TextStyle(
//                                   color: Colors.red,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           ElevatedButton.icon(
//                             onPressed: _loadFilials,
//                             icon: const Icon(Icons.refresh, size: 16),
//                             label: Text('retry'.tr()),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.red.shade600,
//                               foregroundColor: Colors.white,
//                               minimumSize: const Size(0, 32),
//                             ),
//                           ),
//                         ],
//                       ),
//                     )
//                   : DropdownButtonHideUnderline(
//                       child: DropdownButton<int?>(
//                         value: _selectedFilialId,
//                         hint: Padding(
//                           padding: EdgeInsets.symmetric(horizontal: 16),
//                           child: Text('select_branch'.tr()),
//                         ),
//                         isExpanded: true,
//                         menuMaxHeight: 400,
//                         itemHeight: null,
//                         items: [
//                           DropdownMenuItem<int?>(
//                             value: null,
//                             child: Padding(
//                               padding: EdgeInsets.symmetric(
//                                   horizontal: 16, vertical: 8),
//                               child: Row(
//                                 children: [
//                                   Icon(Icons.clear, color: Colors.grey),
//                                   SizedBox(width: 12),
//                                   Text(
//                                     'no_branch_selected'.tr(),
//                                     style: TextStyle(color: Colors.grey),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           ..._filials.map((filial) {
//                             return DropdownMenuItem<int?>(
//                               value: filial.id,
//                               child: Container(
//                                 width: double.infinity,
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 16, vertical: 8),
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     Text(
//                                       filial.name,
//                                       style: const TextStyle(
//                                         fontWeight: FontWeight.w500,
//                                         fontSize: 14,
//                                       ),
//                                       maxLines: 3,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                     if (filial.location != null) ...[
//                                       const SizedBox(height: 4),
//                                       Text(
//                                         filial.location!,
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey.shade600,
//                                         ),
//                                         maxLines: 2,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ],
//                                   ],
//                                 ),
//                               ),
//                             );
//                           }).toList(),
//                         ],
//                         onChanged: (value) {
//                           setState(() {
//                             _selectedFilialId = value;
//                           });
//                         },
//                       ),
//                     ),
//         ),
//       ],
//     );
//   }

//   Widget _buildCategorySelector() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'categories'.tr(),
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Container(
//           width: double.infinity,
//           constraints: BoxConstraints(
//             maxHeight: 300, // Checkbox list uchun max height
//           ),
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: _isLoadingCategories
//               ? Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Row(
//                     children: [
//                       SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       ),
//                       SizedBox(width: 12),
//                       Text('categories_loading'.tr()),
//                     ],
//                   ),
//                 )
//               : _categoryError.isNotEmpty
//                   ? Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.error_outline,
//                                   color: Colors.red.shade600, size: 20),
//                               const SizedBox(width: 8),
//                               Text(
//                                 'categories_loading_error'.tr(),
//                                 style: TextStyle(
//                                   color: Colors.red,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           ElevatedButton.icon(
//                             onPressed:
//                                 _loadCategories, // Bu yerda _loadCategories bo'lishi kerak
//                             icon: const Icon(Icons.refresh, size: 16),
//                             label: Text('retry'.tr()),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.red.shade600,
//                               foregroundColor: Colors.white,
//                               minimumSize: const Size(0, 32),
//                             ),
//                           ),
//                         ],
//                       ),
//                     )
//                   : _categories.isEmpty
//                       ? Padding(
//                           padding: const EdgeInsets.all(16),
//                           child: Text(
//                             'no_categories_available'.tr(),
//                             style: TextStyle(color: Colors.grey.shade600),
//                           ),
//                         )
//                       : Column(
//                           children: [
//                             // Header - tanlangan kategoriyalar soni
//                             Container(
//                               padding: EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.grey.shade50,
//                                 borderRadius: BorderRadius.only(
//                                   topLeft: Radius.circular(11),
//                                   topRight: Radius.circular(11),
//                                 ),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Icon(Icons.category_outlined,
//                                       color: Colors.blue.shade600, size: 20),
//                                   SizedBox(width: 8),
//                                   Text(
//                                     '${_selectedCategoryIds.length} / ${_categories.length} ${'selected'.tr()}',
//                                     style: TextStyle(
//                                       fontWeight: FontWeight.w500,
//                                       color: Colors.blue.shade600,
//                                     ),
//                                   ),
//                                   Spacer(),
//                                   if (_selectedCategoryIds.isNotEmpty)
//                                     TextButton(
//                                       onPressed: () {
//                                         setState(() {
//                                           _selectedCategoryIds.clear();
//                                         });
//                                       },
//                                       style: TextButton.styleFrom(
//                                         minimumSize: Size(0, 0),
//                                         padding: EdgeInsets.symmetric(
//                                             horizontal: 8, vertical: 4),
//                                       ),
//                                       child: Text(
//                                         'clear_all'.tr(),
//                                         style: TextStyle(fontSize: 12),
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                             ),
//                             // Category list with checkboxes
//                             Expanded(
//                               child: ListView.builder(
//                                 shrinkWrap: true,
//                                 itemCount: _categories.length,
//                                 itemBuilder: (context, index) {
//                                   final category = _categories[index];
//                                   final isSelected = _selectedCategoryIds
//                                       .contains(category.id);

//                                   return CheckboxListTile(
//                                     value: isSelected,
//                                     onChanged: (bool? value) {
//                                       setState(() {
//                                         if (value == true) {
//                                           if (!_selectedCategoryIds
//                                               .contains(category.id)) {
//                                             _selectedCategoryIds
//                                                 .add(category.id);
//                                           }
//                                         } else {
//                                           _selectedCategoryIds
//                                               .remove(category.id);
//                                         }
//                                       });
//                                     },
//                                     title: Text(
//                                       category.name,
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.w500,
//                                         fontSize: 14,
//                                       ),
//                                     ),
//                                     subtitle: Text(
//                                       'ID: ${category.id}',
//                                       style: TextStyle(
//                                         fontSize: 12,
//                                         color: Colors.grey.shade600,
//                                       ),
//                                     ),
//                                     activeColor: Colors.blue.shade600,
//                                     dense: true,
//                                     controlAffinity:
//                                         ListTileControlAffinity.trailing,
//                                   );
//                                 },
//                               ),
//                             ),
//                           ],
//                         ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: Container(
//         width: MediaQuery.of(context).size.width * 0.9,
//         constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Colors.blue.shade600, Colors.blue.shade700],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: const BorderRadius.only(
//                   topLeft: Radius.circular(20),
//                   topRight: Radius.circular(20),
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Icon(
//                       widget.user != null ? Icons.edit : Icons.person_add,
//                       color: Colors.white,
//                       size: 24,
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           widget.user != null
//                               ? 'edit_user'.tr()
//                               : 'new_user'.tr(),
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Text(
//                           widget.user != null
//                               ? 'update_data'.tr()
//                               : 'add_new_user'.tr(),
//                           style: const TextStyle(
//                             color: Colors.white70,
//                             fontSize: 14,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     icon: const Icon(Icons.close, color: Colors.white),
//                   ),
//                 ],
//               ),
//             ),

//             // Content
//             Expanded(
//               child: Form(
//                 key: _formKey,
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(24),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Name Field
//                       Text(
//                         'full_name'.tr(),
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       TextFormField(
//                         controller: _nameController,
//                         decoration: InputDecoration(
//                           hintText: 'enter_full_name'.tr(),
//                           prefixIcon: const Icon(Icons.person_outline),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(
//                                 color: Colors.blue.shade600, width: 2),
//                           ),
//                         ),
//                         validator: (value) {
//                           if (value == null || value.trim().isEmpty) {
//                             return 'full_name_required'.tr();
//                           }
//                           return null;
//                         },
//                       ),
//                       const SizedBox(height: 20),

//                       // Phone Field
//                       Text(
//                         'phone_number'.tr(),
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       TextFormField(
//                         controller: _phoneController,
//                         decoration: InputDecoration(
//                           hintText: '+998901234567',
//                           prefixIcon: const Icon(Icons.phone_outlined),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(
//                                 color: Colors.blue.shade600, width: 2),
//                           ),
//                         ),
//                         keyboardType: TextInputType.phone,
//                         validator: (value) {
//                           if (value == null || value.trim().isEmpty) {
//                             return 'phone_number_required'.tr();
//                           }
//                           if (value.trim().isEmpty) {
//                             return 'phone_number_invalid'.tr();
//                           }
//                           return null;
//                         },
//                       ),
//                       const SizedBox(height: 20),

//                       // Password Field
//                       Text(
//                         widget.user != null
//                             ? 'new_password_optional'.tr()
//                             : 'password'.tr(),
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       TextFormField(
//                         controller: _passwordController,
//                         obscureText: _obscurePassword,
//                         decoration: InputDecoration(
//                           hintText: widget.user != null
//                               ? 'new_password_hint'.tr()
//                               : 'enter_password'.tr(),
//                           prefixIcon: const Icon(Icons.lock_outline),
//                           suffixIcon: IconButton(
//                             icon: Icon(_obscurePassword
//                                 ? Icons.visibility_outlined
//                                 : Icons.visibility_off_outlined),
//                             onPressed: () {
//                               setState(() {
//                                 _obscurePassword = !_obscurePassword;
//                               });
//                             },
//                           ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide(
//                                 color: Colors.blue.shade600, width: 2),
//                           ),
//                         ),
//                         validator: (value) {
//                           if (widget.user == null &&
//                               (value == null || value.isEmpty)) {
//                             return 'password_required'.tr();
//                           }
//                           if (value != null &&
//                               value.isNotEmpty &&
//                               value.length < 6) {
//                             return 'Parol kamida 6 ta belgidan iborat bo\'lishi kerak';
//                           }
//                           return null;
//                         },
//                       ),
//                       const SizedBox(height: 20),

//                       // Category Selector (Multiple selection with checkboxes)
//                       _buildCategorySelector(),
//                       const SizedBox(height: 20),

//                       // Filial Selector (Single selection)
//                       _buildFilialSelector(),
//                       const SizedBox(height: 20),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//             // Actions
//             Container(
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade50,
//                 borderRadius: const BorderRadius.only(
//                   bottomLeft: Radius.circular(20),
//                   bottomRight: Radius.circular(20),
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: TextButton(
//                       onPressed:
//                           _isLoading ? null : () => Navigator.of(context).pop(),
//                       style: TextButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       child: Text(
//                         'cancel'.tr(),
//                         style: TextStyle(fontSize: 16),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     flex: 2,
//                     child: ElevatedButton(
//                       onPressed: _isLoading ? null : _saveUser,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue.shade600,
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         elevation: 0,
//                       ),
//                       child: _isLoading
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 color: Colors.white,
//                               ),
//                             )
//                           : Text(
//                               widget.user != null
//                                   ? 'update'.tr()
//                                   : 'create'.tr(),
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
