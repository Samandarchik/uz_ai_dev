#!/bin/bash
# ============================================
#  mone_app APK auto-build with version (macOS)
# ============================================

# Xato yo'li: xabar chiqarib, Enter kutib, chiqish — double-click qilingan
# Terminal oynasi darhol yopilib ketmasligi uchun HAR bir xato shu orqali tugaydi.
fail() {
  echo "$1"
  read -p "Yopish uchun Enter bosing..."
  exit 1
}

# Skript joylashgan papkaga o'tish
cd "$(dirname "$0")" || fail "[XATO] Skript papkasiga o'tib bo'lmadi."

APP_NAME="mone_app"

# --- pubspec.yaml dan versiyani o'qish (version: 0.6.0+60) ---
# Bo'shliq va \r (CRLF) belgilar olib tashlanadi.
VERSION_FULL=$(grep -m1 '^version:' pubspec.yaml | sed 's/version://' | tr -d ' \r')
VERSION=${VERSION_FULL%%+*}
BUILD_NUMBER=${VERSION_FULL#*+}

if [ -z "$VERSION" ]; then
  fail "[XATO] pubspec.yaml dan versiya topilmadi."
fi

# Fayl nomi: build raqami bo'lsa 0.6.0+60 -> mone_app_0.6.0_b60.apk,
# bo'lmasa (version: 0.6.0) -> mone_app_0.6.0.apk
if [ -n "$BUILD_NUMBER" ] && [ "$BUILD_NUMBER" != "$VERSION_FULL" ]; then
  ARTIFACT="${APP_NAME}_${VERSION}_b${BUILD_NUMBER}.apk"
else
  ARTIFACT="${APP_NAME}_${VERSION}.apk"
fi

echo "============================================"
echo "  Build: ${ARTIFACT}"
echo "============================================"
echo

# --- APK build ---
flutter build apk --release || fail "[XATO] Build muvaffaqiyatsiz tugadi."

SRC="build/app/outputs/flutter-apk/app-release.apk"
DEST="build/app/outputs/flutter-apk/${ARTIFACT}"

if [ ! -f "$SRC" ]; then
  fail "[XATO] APK topilmadi: $SRC"
fi

cp -f "$SRC" "$DEST" || fail "[XATO] APK nusxalab bo'lmadi: $DEST"

echo
echo "============================================"
echo "  TAYYOR!"
echo "  Fayl: $DEST"
echo "============================================"

# --- APK papkasini Finder'da ochish ---
open build/app/outputs/flutter-apk

read -p "Yopish uchun Enter bosing..."
