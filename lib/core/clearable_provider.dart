// core/clearable_provider.dart — logout'da provider holatini tozalash uchun mixin.
mixin ClearableProvider {
  /// Logout'da barcha xotiradagi (foydalanuvchiga oid) ma'lumotni boshlang'ich
  /// holatga qaytaradi; socketli providerlar ulanishni ham uzadi.
  void clear();
}
