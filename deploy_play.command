#!/usr/bin/env bash
#
# Mone — Android build va Google Play'ga avtomatik yuklash.
# Finder'da ikki marta bosib ham, terminaldan ham ishlatsa bo'ladi.
#
#   ./deploy_play.command                  HAMMASI: versiya oshadi, build bo'ladi,
#                                          internal testga + production'ga (Google ko'rigiga) ketadi
#   ./deploy_play.command --internal       faqat testerlarga (production'ga tegilmaydi)
#   ./deploy_play.command --bump           versiyani majburan oshiradi (odatda o'zi hal qiladi)
#   ./deploy_play.command --promote        build QILMAYDI: Play'dagi oxirgi build'ni production'ga chiqaradi
#   ./deploy_play.command --minor          keyingi o'nlik (0.6.5+65 -> 0.7.0+70)
#   ./deploy_play.command --major          keyingi yuzlik (0.6.5+65 -> 1.0.0+100)
#   ./deploy_play.command --version 1.3.0  versiyani qo'lda belgilash (kod 130 bo'ladi)
#   ./deploy_play.command --no-bump        hech nimaga tegmaydi (aynan shu build'ni qayta yuklash)
#   ./deploy_play.command --track a,b      track ro'yxati (internal|alpha|beta|production), vergul bilan
#   ./deploy_play.command --rollout 0.2    production'ga bosqichma-bosqich (20% foydalanuvchi)
#   ./deploy_play.command --notes "matn"   relizga izoh (testerlar/foydalanuvchilar ko'radi)
#   ./deploy_play.command --yes            production ogohlantirishini kutmaydi (5 s pauza yo'q)
#   ./deploy_play.command --validate       yuklamaydi, faqat Play tekshiruvidan o'tkazadi
#   ./deploy_play.command --clean          flutter keshini tozalab build qiladi
#
# Nima bo'ladi (parametrsiz): AAB build qilinadi -> Play'ga BIR MARTA yuklanadi -> bitta
# edit ichida `internal` va `production` tracklarga qo'yiladi -> commit.
#   internal   -> testerlarga darhol, Play Store'da yangilanish O'ZI chiqadi
#   production -> Google ko'rigiga (review) tushadi, o'tgach hamma foydalanuvchiga chiqadi
# Production hamma foydalanuvchiga tegishi uchun skript 5 soniya kutadi (Ctrl+C = bekor).
#
# KO'RIKKA YUBORISH: commit `changesNotSentForReview=false` bilan qilinadi — bu Play Console'dagi
# "Отправить на проверку" tugmasining o'zi. Console'da avval 3-5 daqiqa "Проверка на наличие
# распространенных проблем" (Google avto-tekshiruvi) ko'rinadi, u tugagach reliz
# "На рассмотрении" bo'ladi. Shu bosqichda "yuborildi" degan yozuv chiqmaydi — bu normal.
# Faqat ikki holatda qo'lda bosish kerak (skript buni oxirida baland aytadi):
#   1) Google API "avtomatik yuborib bo'lmaydi" (400) desa — yuklangan build yo'qolmasin deb
#      skript `changesNotSentForReview=true` bilan qayta commit qiladi, keyin Console ->
#      Обзор публикации -> "Отправить на проверку" bosiladi;
#   2) avto-tekshiruv muammo topsa — o'sha sahifada ogohlantirish bilan birga tugma chiqadi.
# Tekshirish havolasi: PLAY_CONSOLE_URL (config'da; bo'lmasa Mone'niki standart).
#
# Testerlar ro'yxati BIR MARTA Play Console'da sozlanadi:
#   Play Console -> Testing -> Internal testing -> Testers -> email ro'yxati (yoki Google guruh),
#   keyin "Copy link" — testerlar shu link orqali bir marta qo'shiladi (opt-in).
# Shundan keyin har bir yuklash avtomat o'sha odamlarga boradi.
#
# VERSIYA QOIDASI: versiya raqami = versionCode raqamlari, ikkalasi doim bir xil boradi:
#   0.6.8+68  ->  0.6.9+69  ->  0.7.0+70  ->  0.7.1+71  ...  0.9.9+99  ->  1.0.0+100
# Ya'ni versiya versionCode'dan hisoblanadi (69 -> 0.6.9), qo'lda yozilmaydi. Shuning
# uchun 0.6.10 kabi (kodga tushmaydigan) raqam hech qachon chiqmaydi.
#
# Standart holatda pubspec'dagi raqam Play'da hali yo'q bo'lsa — AYNAN o'sha ishlatiladi
# (oshirilmaydi). Shu sababli iOS (deploy_ios.command) bilan ketma-ket ishga tushirilsa,
# ikkala do'konda ham bir xil versiya chiqadi. Majburan oshirish: --bump.
#
# Play bir xil versionCode'ni ikkinchi marta qabul qilmaydi va u doim o'sishi shart —
# skript Play'dagi eng katta versionCode'ni tekshirib, kerak bo'lsa undan yuqori qilib oladi
# (qadam turi saqlanadi: --minor keyingi o'nlikka, --major keyingi yuzlikka).
# Tekshiruv bo'lmasa skript to'xtaydi (taxminiy raqam bilan build qilinmaydi). Yuklashda
# baribir "Version code N has already been used" chiqsa — raqam N+1 qilinib AAB qayta
# build bo'ladi va qayta yuklanadi, qo'lda hech nima qilinmaydi. Build'dan keyin AAB'ning
# haqiqiy versionCode'i pubspec bilan solishtiriladi (local.properties eskirib qolsa ushlanadi).
#
# Konfiguratsiya: ~/.mone_play.env (bo'lmasa ~/.sadinov_play.env ishlatiladi):
#   PLAY_SA_JSON=$HOME/.playconsole/mone-service-account.json
#   PLAY_CONSOLE_URL=https://play.google.com/console/u/0/developers/<dev_id>/app/<app_id>   (ixtiyoriy)
#
# Service account: Google Cloud Console -> IAM -> Service Accounts'da yaratiladi, JSON kalit
# yuklab olinadi, keyin Play Console -> Users and permissions orqali shu ilovaga
# "Release manager" (yoki hech bo'lmasa "Release to testing tracks") huquqi beriladi.
#
# Eslatma: ilovaning ENG BIRINCHI buildi API orqali yuklanmaydi — uni Play Console
# veb-sahifasidan qo'lda yuklash kerak. Keyingilari shu skript bilan.

set -euo pipefail

cd "$(dirname "$0")"

# Finder'dan (ikki bosish) ochilganda oynani natija bilan ochiq qoldirish
cleanup_and_pause() {
    local code=$?
    rm -f "${PRECHECK_PY:-}" "${USED_FILE:-}"
    if [ -t 0 ]; then
        echo
        [ $code -eq 0 ] || echo "[XATO] Skript $code kodi bilan tugadi."
        read -r -p "Yopish uchun Enter bosing..."
    fi
}
PRECHECK_PY=""
USED_FILE=""
trap cleanup_and_pause EXIT

# Finder'dan ikki marta bosib ochilganda PATH faqat /usr/bin:/bin:/usr/sbin:/sbin bo'ladi —
# flutter u yerda yo'q. Avval odatdagi joylardan, keyin foydalanuvchi zsh sozlamasidan qidiramiz.
# MUHIM: `zsh -lc` .zshrc ni O'QIMAYDI (u faqat interaktiv shellda o'qiladi), shuning uchun
# `-i` kerak — PATH aynan ~/.zshrc da qo'shilgan.
if ! command -v flutter >/dev/null 2>&1; then
    for d in "$HOME/developer/flutter/bin" "$HOME/development/flutter/bin" \
             "$HOME/flutter/bin" /opt/homebrew/bin /usr/local/bin; do
        [ -x "$d/flutter" ] && PATH="$d:$PATH" && break
    done
fi
if ! command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(/bin/zsh -ilc 'command -v flutter' 2>/dev/null | tail -1 || true)"
    if [ -n "$FLUTTER_BIN" ] && [ -x "$FLUTTER_BIN" ]; then
        PATH="$(dirname "$FLUTTER_BIN"):$PATH"
    fi
fi
command -v flutter >/dev/null 2>&1 || { echo "flutter topilmadi (PATH)." >&2; exit 1; }

BUMP=auto           # auto | force | minor | major | none
VALIDATE=0
CLEAN=0
PROMOTE=0
ASSUME_YES=0
NEW_VERSION=""
TRACKS=""           # bo'sh = quyidagi standart qo'llanadi
ROLLOUT=""
NOTES="${PLAY_NOTES:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --no-bump)            BUMP=none ;;
        --bump|--patch|--build|--build-only) BUMP=force ;;
        --minor)              BUMP=minor ;;
        --major)              BUMP=major ;;
        --internal|--test)    TRACKS="internal" ;;
        --promote)  PROMOTE=1 ;;
        --validate) VALIDATE=1 ;;
        --clean)    CLEAN=1 ;;
        --yes|-y)   ASSUME_YES=1 ;;
        --version)  NEW_VERSION="${2:-}"; shift ;;
        --track)    TRACKS="${2:-}"; shift ;;
        --rollout)  ROLLOUT="${2:-}"; shift ;;
        --notes)    NOTES="${2:-}"; shift ;;
        -h|--help)  awk 'NR>2 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
        *)          echo "Noma'lum parametr: $1"; exit 1 ;;
    esac
    shift
done

# Standart: hammasi birdan. --promote da faqat production (build allaqachon Play'da).
if [ -z "$TRACKS" ]; then
    if [ "$PROMOTE" -eq 1 ]; then
        TRACKS="production"
    else
        TRACKS="internal,production"
    fi
fi

# Vergulli ro'yxatni tekshirish
OLD_IFS="$IFS"; IFS=','
for t in $TRACKS; do
    case "$t" in
        internal|alpha|beta|production) ;;
        *) IFS="$OLD_IFS"; echo "Noto'g'ri track: $t (internal|alpha|beta|production)" >&2; exit 1 ;;
    esac
done
IFS="$OLD_IFS"

if [ -n "$ROLLOUT" ]; then
    case "$ROLLOUT" in
        0.*|1|1.0) ;;
        *) echo "Noto'g'ri --rollout: $ROLLOUT (0.01 dan 1 gacha)" >&2; exit 1 ;;
    esac
fi

# --promote build qilmaydi va versiyaga tegmaydi
if [ "$PROMOTE" -eq 1 ]; then
    BUMP=none
fi

# --- 1. Konfiguratsiya ---

CONFIG="${PLAY_CONFIG:-}"
if [ -z "$CONFIG" ]; then
    for c in "$HOME/.mone_play.env" "$HOME/.sadinov_play.env"; do
        [ -f "$c" ] && CONFIG="$c" && break
    done
fi
if [ -z "$CONFIG" ] || [ ! -f "$CONFIG" ]; then
    cat >&2 <<EOF
Konfiguratsiya topilmadi.

Quyidagicha yarating:
    cat > $HOME/.mone_play.env <<'CONF'
    PLAY_SA_JSON=\$HOME/.playconsole/mone-service-account.json
    CONF
    chmod 600 $HOME/.mone_play.env

Service account JSON kalitini Google Cloud Console -> Service Accounts'dan yuklab oling
va Play Console -> Users and permissions'da unga shu ilova uchun release huquqini bering.
EOF
    exit 1
fi
echo "Konfiguratsiya: $CONFIG"

# shellcheck disable=SC1090
source "$CONFIG"

# Eslatma: bash 3.2 da "${VAR:?xabar}" ichida apostrof ishlatib bo'lmaydi
if [ -z "${PLAY_SA_JSON:-}" ]; then
    echo "$CONFIG ichida PLAY_SA_JSON yo'q" >&2
    exit 1
fi
PLAY_SA_JSON="${PLAY_SA_JSON/#\~/$HOME}"

# Play Console'dagi ilova sahifasi — faqat oxirida "qayerdan tekshirish" havolasi uchun.
# (API'dan olib bo'lmaydi: dev_id/app_id faqat Console URL'ida bor.)
PLAY_CONSOLE_URL="${PLAY_CONSOLE_URL:-https://play.google.com/console/u/0/developers/7404657258437147773/app/4974439267294493309}"

if [ ! -f "$PLAY_SA_JSON" ]; then
    echo "Service account JSON topilmadi: $PLAY_SA_JSON" >&2
    exit 1
fi

# Kerakli kutubxonalari BOR python3 ni topamiz. Finder'dan ochilganda `python3` = Apple'niki
# (/usr/bin/python3) bo'lib qoladi, unda google kutubxonalari yo'q — homebrew'nikini qidiramiz.
PY_BIN=""
for cand in "${PLAY_PYTHON:-}" python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    [ -n "$cand" ] || continue
    if command -v "$cand" >/dev/null 2>&1 &&
       "$cand" -c "import googleapiclient, google.oauth2" >/dev/null 2>&1; then
        PY_BIN="$cand"
        break
    fi
done
if [ -z "$PY_BIN" ]; then
    cand="$(/bin/zsh -ilc 'command -v python3' 2>/dev/null | tail -1 || true)"
    if [ -n "$cand" ] && "$cand" -c "import googleapiclient, google.oauth2" >/dev/null 2>&1; then
        PY_BIN="$cand"
    fi
fi
if [ -z "$PY_BIN" ]; then
    echo "Google Play kutubxonalari bor python3 topilmadi. O'rnating:" >&2
    echo "    python3 -m pip install google-api-python-client google-auth" >&2
    echo "(yoki PLAY_PYTHON=/to'liq/yo'l/python3 ni ~/.mone_play.env ichida ko'rsating)" >&2
    exit 1
fi

PKG="$(sed -n 's/.*applicationId *= *"\(.*\)".*/\1/p' android/app/build.gradle 2>/dev/null | head -1)"
[ -n "$PKG" ] || { echo "applicationId topilmadi (android/app/build.gradle)." >&2; exit 1; }
echo "Ilova: $PKG"

# --- Build yordamchilari ---

# android/local.properties'dagi bitta kalitni yozadi (yo'q bo'lsa qo'shadi).
set_local_prop() {
    local f=android/local.properties key="$1" val="$2"
    [ -f "$f" ] || : > "$f"
    if grep -q "^${key}=" "$f"; then
        sed -i '' "s|^${key}=.*|${key}=${val}|" "$f"
    else
        # fayl oxirida yangi qator bo'lmasa qo'shamiz, aks holda kalit oldingi qatorga yopishadi
        if [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then echo >> "$f"; fi
        printf '%s=%s\n' "$key" "$val" >> "$f"
    fi
}

# AAB build: SEMVER/BUILD_NUM dan. Gradle plagini versionCode'ni AYNAN android/local.properties
# dan o'qiydi (FlutterPlugin.kt: flutter.versionCode); uni flutter tool build'da yangilashi
# kerak, lekin 2026-08-25 da Finder'dan ishga tushganda yangilamadi — pubspec 107 bo'lsa ham
# AAB eski 106 bilan chiqib Play "Version code 106 has already been used" dedi. Shuning uchun:
#   1) faylni o'zimiz yozamiz,  2) --build-name/--build-number ni aniq beramiz,
#   3) build'dan keyin AAB'ning haqiqiy versionCode'ini tekshiramiz (Play'ga yuborishdan OLDIN).
build_aab() {
    if [ "$CLEAN" -eq 1 ]; then
        echo "Kesh tozalanmoqda..."
        flutter clean >/dev/null
        CLEAN=0
    fi
    set_local_prop flutter.versionName "$SEMVER"
    set_local_prop flutter.versionCode "$BUILD_NUM"

    echo "AAB build qilinmoqda (versiya $SEMVER, versionCode $BUILD_NUM)..."
    flutter build appbundle --release --build-name "$SEMVER" --build-number "$BUILD_NUM"

    AAB="build/app/outputs/bundle/release/app-release.aab"
    [ -f "$AAB" ] || { echo "AAB fayl topilmadi — build muvaffaqiyatsiz." >&2; exit 1; }

    local manifest="build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml"
    local built=""
    if [ -f "$manifest" ]; then
        built="$(grep -o 'android:versionCode="[0-9]*"' "$manifest" | head -1 | tr -dc '0-9')"
    fi
    if [ -n "$built" ] && [ "$built" != "$BUILD_NUM" ]; then
        echo "AAB ichidagi versionCode $built, kutilgan esa $BUILD_NUM — build eski raqam bilan ketdi." >&2
        echo "android/local.properties va gradle keshini tekshiring; --clean bilan qayta uring." >&2
        exit 1
    fi
    if [ -n "$built" ]; then
        echo "AAB tayyor: $AAB ($(du -h "$AAB" | cut -f1)), versionCode $built tekshirildi"
    else
        echo "AAB tayyor: $AAB ($(du -h "$AAB" | cut -f1))"
    fi
    MAPPING="build/app/outputs/mapping/release/mapping.txt"
}

# --- 2. Versiya ---
# Play'dagi eng katta versionCode'ni oldindan so'raymiz: shu bilan (a) auth/huquq xatosi
# 10 daqiqalik build'dan OLDIN chiqadi, (b) versionCode aniq o'sadi.

version_line() { grep '^version:' pubspec.yaml | head -1 | sed 's/^version: *//' | tr -d ' \r'; }

CURRENT="$(version_line)"
SEMVER="${CURRENT%%+*}"
BUILD_NUM="${CURRENT##*+}"

# Versiya raqami HAR DOIM versionCode'ning raqamlaridan tuziladi:
#   69 -> 0.6.9    70 -> 0.7.0    100 -> 1.0.0    1000 -> 10.0.0
# Ya'ni ikkalasi doim bir xil bo'lib boradi va 0.6.10 kabi holat umuman chiqmaydi.
version_from_code() {
    echo "$(($1 / 100)).$(($1 / 10 % 10)).$(($1 % 10))"
}

# Aksincha: 0.7.0 -> 70. Oxirgi ikki bo'lak bitta raqamdan oshmasligi kerak.
code_from_version() {
    local major minor patch
    IFS=. read -r major minor patch <<< "$1"
    major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}
    if [ "$minor" -gt 9 ] || [ "$patch" -gt 9 ]; then
        echo "Versiya raqamlari versionCode bilan bog'liq: o'rta va oxirgi bo'lak 0-9 bo'lishi kerak ($1)." >&2
        return 1
    fi
    echo $((major * 100 + minor * 10 + patch))
}

echo "Play'dagi mavjud versionCode tekshirilmoqda..."

# Eslatma: bash 3.2 (macOS) `$( ... <<HEREDOC ... )` ichidagi apostroflarni noto'g'ri
# o'qiydi — shuning uchun bu python vaqtinchalik faylga yoziladi (trap uni o'chiradi).
PRECHECK_PY="$(mktemp -t mone_play_precheck)"
cat > "$PRECHECK_PY" <<'PY'
import os, sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

creds = service_account.Credentials.from_service_account_file(
    os.environ["SA_JSON"], scopes=["https://www.googleapis.com/auth/androidpublisher"])
svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
pkg = os.environ["PKG"]

try:
    edit_id = svc.edits().insert(packageName=pkg).execute()["id"]
except HttpError as e:
    if e.resp.status in (401, 403, 404):
        print(f"Ilova topilmadi yoki huquq yo'q ({pkg}).", file=sys.stderr)
        print("Service account'ga Play Console -> Users and permissions'da release huquqi", file=sys.stderr)
        print("berilganini va birinchi build qo'lda yuklanganini tekshiring.", file=sys.stderr)
        sys.exit(2)     # 2 = huquq/ilova xatosi: build qilishdan oldin to'xtaymiz
    raise

codes = [0]
try:
    # Tracklardagi relizlar — eng ishonchli manba (bundles.list ba'zan bo'sh qaytaradi)
    for t in svc.edits().tracks().list(
            packageName=pkg, editId=edit_id).execute().get("tracks", []):
        for r in t.get("releases", []):
            codes += [int(c) for c in r.get("versionCodes", []) or []]
    codes += [b["versionCode"] for b in svc.edits().bundles().list(
        packageName=pkg, editId=edit_id).execute().get("bundle", [])]
    codes += [a["versionCode"] for a in svc.edits().apks().list(
        packageName=pkg, editId=edit_id).execute().get("apks", [])]
finally:
    try:
        svc.edits().delete(packageName=pkg, editId=edit_id).execute()
    except Exception:
        pass

print(max(codes))
PY

# Tarmoq/API xatosida 3 marta urinamiz. Baribir bo'lmasa TO'XTAYMIZ — avval "lokal raqam
# ishlatiladi" deb jimgina davom etardi, natijada Play'da bor raqam bilan build ketib
# 10 daqiqadan keyin "Version code N has already been used" chiqardi.
PLAY_MAX=""
PRECHECK_RC=0
for attempt in 1 2 3; do
    set +e
    PLAY_MAX="$(SA_JSON="$PLAY_SA_JSON" PKG="$PKG" "$PY_BIN" "$PRECHECK_PY")"
    PRECHECK_RC=$?
    set -e
    # Huquq / ilova topilmadi xatosi — qayta urinish ma'nosiz, build'dan oldin to'xtaymiz.
    # (`set -e` bor: `[ ... ] && exit` emas, `if` ishlatilgan.)
    if [ "$PRECHECK_RC" -eq 2 ]; then
        exit 1
    fi
    case "$PLAY_MAX" in
        ''|*[!0-9]*) echo "  (urinish $attempt/3: Play'dan javob olib bo'lmadi, 3 s dan keyin qayta...)"; sleep 3 ;;
        *) break ;;
    esac
done

case "$PLAY_MAX" in
    ''|*[!0-9]*)
        echo "Play'dagi versionCode ro'yxatini olib bo'lmadi (tarmoq yoki API xatosi, yuqoridagi xabar)." >&2
        echo "Taxminiy raqam bilan davom etilmaydi — aks holda build bekor ketadi ('already been used')." >&2
        exit 1 ;;
    *) echo "  Play'dagi eng katta versionCode: $PLAY_MAX" ;;
esac

# Yangi versionCode: qadam turiga qarab. Versiya raqami keyin shundan chiqariladi,
# shuning uchun ikkalasi hech qachon ajralib ketmaydi (0.6.9+69 -> 0.7.0+70 -> 0.7.1+71).
if [ -n "$NEW_VERSION" ]; then
    BUILD_NUM="$(code_from_version "$NEW_VERSION")" || exit 1
    # Qo'lda berilgan versiya jimgina o'zgartirilmasin — pastda qolsa aytamiz
    if [ "$PROMOTE" -eq 0 ] && [ "$BUILD_NUM" -le "$PLAY_MAX" ]; then
        echo "Versiya $NEW_VERSION -> versionCode $BUILD_NUM, lekin Play'da allaqachon $PLAY_MAX bor." >&2
        echo "Kattaroq versiya bering (masalan $(version_from_code $((PLAY_MAX + 1))))." >&2
        exit 1
    fi
else
    case "$BUMP" in
        # auto: pubspec'dagi raqam Play'da hali yo'q bo'lsa AYNAN o'shani ishlatamiz —
        # shunda iOS (deploy_ios.command) bilan bir xil versiya chiqadi
        auto)  [ "$BUILD_NUM" -le "$PLAY_MAX" ] && BUILD_NUM=$((PLAY_MAX + 1)) ;;
        force) BUILD_NUM=$(( (BUILD_NUM > PLAY_MAX ? BUILD_NUM : PLAY_MAX) + 1 )) ;;
        minor) BUILD_NUM=$(( ((BUILD_NUM > PLAY_MAX ? BUILD_NUM : PLAY_MAX) / 10 + 1) * 10 )) ;;
        major) BUILD_NUM=$(( ((BUILD_NUM > PLAY_MAX ? BUILD_NUM : PLAY_MAX) / 100 + 1) * 100 )) ;;
        none)  ;;
    esac
fi

AAB=""
MAPPING=""

if [ "$PROMOTE" -eq 1 ]; then
    # Build qilinmaydi: Play'dagi eng oxirgi build shunchaki boshqa trackka qo'yiladi
    if [ "$PLAY_MAX" -le 0 ]; then
        echo "Play'da chiqariladigan build topilmadi." >&2
        exit 1
    fi
    BUILD_NUM="$PLAY_MAX"
    SEMVER="$(version_from_code "$BUILD_NUM")"
    TARGET="${SEMVER}+${BUILD_NUM}"
    echo "Promote rejimi: build qilinmaydi, Play'dagi versionCode $BUILD_NUM ishlatiladi."
else
    # Play'da bor bo'lgan versionCode qayta qabul qilinmaydi — undan yuqoriga ko'taramiz
    # (qadam turi saqlanadi: --minor keyingi o'nlikka, --major keyingi yuzlikka)
    if [ "$BUMP" != "none" ] && [ "$BUILD_NUM" -le "$PLAY_MAX" ]; then
        case "$BUMP" in
            minor) BUILD_NUM=$(( (PLAY_MAX / 10 + 1) * 10 )) ;;
            major) BUILD_NUM=$(( (PLAY_MAX / 100 + 1) * 100 )) ;;
            *)     BUILD_NUM=$((PLAY_MAX + 1)) ;;
        esac
        echo "  Build raqami Play'ga moslab ko'tarildi: $BUILD_NUM"
    elif [ "$BUMP" = "none" ] && [ "$BUILD_NUM" -le "$PLAY_MAX" ] && [ "$VALIDATE" -eq 0 ]; then
        echo "  [OGOHLANTIRISH] versionCode $BUILD_NUM Play'da allaqachon bor — yuklash rad etiladi." >&2
    fi

    # Versiya raqami — doim versionCode'dan (--no-bump da ham moslab qo'yamiz)
    SEMVER="$(version_from_code "$BUILD_NUM")"

    TARGET="${SEMVER}+${BUILD_NUM}"
    if [ "$TARGET" != "$CURRENT" ]; then
        # macOS sed — .bak faylsiz o'zgartirish
        sed -i '' "s/^version: .*/version: ${TARGET}/" pubspec.yaml
        echo "Versiya: $CURRENT -> $TARGET"
    else
        echo "Versiya: $TARGET (o'zgarmadi)"
    fi

    # --- 3. Build ---

    build_aab
fi

# --- 4. Google Play ---

# Production hamma foydalanuvchiga tegadi — bekor qilishga imkon beramiz.
# (Ctrl+C bosilmasa o'zi davom etadi, ya'ni avtomatikaga xalal bermaydi.)
if [ "$VALIDATE" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ] && echo ",$TRACKS," | grep -q ',production,'; then
    echo
    echo "  !!! PRODUCTION: bu build Google ko'rigiga tushadi va o'tgach HAMMA"
    echo "      foydalanuvchiga chiqadi. Bekor qilish uchun Ctrl+C — 5 soniya..."
    sleep 5
    echo
fi

if [ "$VALIDATE" -eq 1 ]; then
    echo "Google Play tekshiruvidan o'tkazilmoqda (validate)..."
else
    echo "Google Play'ga yuborilmoqda (tracklar: $TRACKS)..."
fi

# Yuklash alohida funksiya: "versionCode allaqachon ishlatilgan" (exit 3) bo'lsa raqamni
# oshirib qayta build qilib, YANA shu funksiya chaqiriladi.
USED_FILE="$(mktemp -t play_used_code)"
upload_to_play() {
SA_JSON="$PLAY_SA_JSON" PKG="$PKG" AAB="$AAB" MAPPING="$MAPPING" \
TRACKS="$TRACKS" VALIDATE="$VALIDATE" RELEASE_NAME="$TARGET" NOTES="$NOTES" \
PROMOTE="$PROMOTE" VERSION_CODE="$BUILD_NUM" ROLLOUT="$ROLLOUT" USED_FILE="$USED_FILE" \
CONSOLE_URL="$PLAY_CONSOLE_URL" \
"$PY_BIN" - <<'PY'
import os, re, socket, sys

# googleapiclient http'ni socket.getdefaulttimeout() (bo'lmasa 60 s) bilan quradi —
# katta fayllarda sekin tarmoqda "write operation timed out" beradi, kengaytiramiz.
socket.setdefaulttimeout(600)

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

sa_json  = os.environ["SA_JSON"]
pkg      = os.environ["PKG"]
aab      = os.environ["AAB"]
mapping  = os.environ["MAPPING"]
tracks   = [t for t in os.environ["TRACKS"].split(",") if t]
validate = os.environ["VALIDATE"] == "1"
promote  = os.environ["PROMOTE"] == "1"
name     = os.environ["RELEASE_NAME"]
notes    = os.environ.get("NOTES", "").strip()
rollout  = os.environ.get("ROLLOUT", "").strip()
console  = os.environ.get("CONSOLE_URL", "").rstrip("/")

creds = service_account.Credentials.from_service_account_file(
    sa_json, scopes=["https://www.googleapis.com/auth/androidpublisher"])
svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

try:
    edit_id = svc.edits().insert(packageName=pkg).execute()["id"]
except HttpError as e:
    if e.resp.status in (401, 403, 404):
        print(f"Ilova topilmadi yoki huquq yo'q ({pkg}).", file=sys.stderr)
        print("Service account'ga Play Console'da release huquqi berilganini va", file=sys.stderr)
        print("ilovaning birinchi buildi qo'lda yuklanganini tekshiring.", file=sys.stderr)
        sys.exit(1)
    raise

if promote:
    version_code = int(os.environ["VERSION_CODE"])
    print(f"Play'dagi tayyor build ishlatilyapti: versionCode {version_code}")
else:
    print("AAB yuklanmoqda...")
    media = MediaFileUpload(aab, mimetype="application/octet-stream",
                            chunksize=8 * 1024 * 1024, resumable=True)
    try:
        bundle = svc.edits().bundles().upload(
            packageName=pkg, editId=edit_id, media_body=media).execute(num_retries=5)
    except HttpError as e:
        # "Version code N has already been used" — precheck ko'rmagan raqam (masalan trackka
        # qo'yilmagan, faqat yuklangan bundle). Raqamni bash'ga qaytarib (exit 3) qayta build
        # qildiramiz — foydalanuvchi qo'l bilan hech nima qilmaydi.
        text = (e.content.decode("utf-8", "ignore") if isinstance(e.content, bytes) else str(e.content)) + str(e)
        m = re.search(r"[Vv]ersion code (\d+) has already been used", text)
        if m:
            print(f"  Play: versionCode {m.group(1)} allaqachon ishlatilgan.", file=sys.stderr)
            try:
                svc.edits().delete(packageName=pkg, editId=edit_id).execute()
            except Exception:
                pass
            if os.environ.get("USED_FILE"):
                with open(os.environ["USED_FILE"], "w") as f:
                    f.write(m.group(1))
            sys.exit(3)
        raise
    version_code = bundle["versionCode"]
    print(f"Yuklandi: versionCode {version_code}")

    if os.path.isfile(mapping):
        # Mapping o'nlab MB bo'ladi — AAB kabi bo'laklab (resumable) yuklanmasa bitta
        # ulkan so'rov timeout'ga uchraydi. Yuklanmasa ham reliz TO'XTAMAYDI:
        # mapping faqat crash-hisobotlarni deobfuskatsiya qilish uchun kerak.
        print("ProGuard mapping yuklanmoqda...")
        try:
            svc.edits().deobfuscationfiles().upload(
                packageName=pkg, editId=edit_id, apkVersionCode=version_code,
                deobfuscationFileType="proguard",
                media_body=MediaFileUpload(mapping, mimetype="application/octet-stream",
                                           chunksize=8 * 1024 * 1024, resumable=True),
            ).execute(num_retries=5)
        except Exception as e:
            print(f"  [OGOHLANTIRISH] mapping yuklanmadi: {e}", file=sys.stderr)
            print("  Reliz davom etadi — faqat crash-hisobotlar deobfuskatsiyasiz ko'rinadi.",
                  file=sys.stderr)

release = {
    "name": name,
    "versionCodes": [str(version_code)],
    # completed = darhol e'lon qilinadi, ya'ni testerlarga o'zi boradi
    "status": "completed",
}
if notes:
    # Izoh tili ilovaning Play listing tillaridan bo'lishi shart, aks holda 400 qaytadi —
    # shuning uchun mavjud tillar ro'yxatidan mos kelganini olamiz.
    try:
        langs = [l["language"] for l in svc.edits().listings().list(
            packageName=pkg, editId=edit_id).execute().get("listings", [])]
    except HttpError:
        langs = []
    chosen = [l for l in ("uz", "ru-RU", "en-US") if l in langs] or langs[:1] or ["en-US"]
    release["releaseNotes"] = [{"language": l, "text": notes} for l in chosen]

for track in tracks:
    rel = dict(release)
    # Bosqichma-bosqich chiqarish faqat production uchun ma'noli
    if rollout and track == "production":
        rel["status"] = "inProgress"
        rel["userFraction"] = float(rollout)
    svc.edits().tracks().update(
        packageName=pkg, editId=edit_id, track=track, body={"releases": [rel]},
    ).execute()
    print(f"  track '{track}' tayyorlandi")

if validate:
    svc.edits().validate(packageName=pkg, editId=edit_id).execute()
    print("Tekshiruvdan o'tdi (yuklanmadi).")
    sys.exit(0)

# changesNotSentForReview=False = Console'dagi "Отправить на проверку" tugmasi: commit bilan
# birga o'zgarishlar Google ko'rigiga ketadi. Google buni ba'zi holatlarda (ilovada tugallanmagan
# deklaratsiya, oldingi ko'rik hali tugamagan, akkaunt cheklovi) 400 bilan rad etadi:
#   "Changes cannot be sent for review automatically. Please set ... changesNotSentForReview ..."
# Unda yuklangan AAB yo'qolmasin deb True bilan qayta commit qilamiz — build Play'da saqlanadi,
# faqat ko'rikka yuborish Console'da qo'lda bosiladi (pastda aytiladi).
sent_for_review = True
try:
    svc.edits().commit(packageName=pkg, editId=edit_id,
                       changesNotSentForReview=False).execute()
except HttpError as e:
    body = (e.content or b"").decode("utf-8", "ignore") if isinstance(e.content, bytes) else str(e.content)
    if e.resp.status == 400 and "changesNotSentForReview" in body + str(e):
        print("  [OGOHLANTIRISH] Google ko'rikka avtomatik yuborishga ruxsat bermadi —", file=sys.stderr)
        print("  build saqlanadi, ko'rikka yuborish Console'da qo'lda bosiladi.", file=sys.stderr)
        svc.edits().commit(packageName=pkg, editId=edit_id,
                           changesNotSentForReview=True).execute()
        sent_for_review = False
    else:
        raise
print(f"Tayyor — build {name} quyidagi tracklarda: {', '.join(tracks)}")

if "internal" in tracks:
    print("  internal: testerlarga bir necha daqiqada Play Store'da yangilanish chiqadi.")
    print("            (ro'yxat: Play Console -> Testing -> Internal testing -> Testers)")
if "production" in tracks:
    if not sent_for_review:
        print()
        print("  !!! PRODUCTION KO'RIKKA YUBORILMADI (Google avtomatik yuborishni rad etdi).")
        print("      Play Console -> Обзор публикации -> \"Отправить на проверку\" tugmasini bosing:")
        if console:
            print(f"      {console}/publishing")
    elif rollout:
        print(f"  production: Google ko'rigiga yuborildi, foydalanuvchilarning {float(rollout)*100:.0f}% iga chiqadi.")
    else:
        print("  production: Google ko'rigiga (review) yuborildi — odatda bir necha soatdan")
        print("              bir necha kungacha, o'tgach hamma foydalanuvchiga chiqadi.")
    if sent_for_review:
        print("      Console'da avval 3-5 daqiqa \"Проверка на наличие распространенных проблем\"")
        print("      (Google avto-tekshiruvi) ko'rinadi, keyin reliz \"На рассмотрении\" bo'ladi.")
        print("      Avto-tekshiruv muammo topsa — o'sha sahifada qo'lda \"Отправить на проверку\" bosiladi.")
        if console:
            print(f"      Tekshirish: {console}/publishing")
            print(f"      Reliz holati: {console}/tracks/production")
PY
}

set +e
upload_to_play
UP_RC=$?
set -e
if [ "$UP_RC" -eq 3 ] && [ "$PROMOTE" -eq 0 ]; then
    USED="$(tr -dc '0-9' < "$USED_FILE" 2>/dev/null || true)"
    [ -n "$USED" ] || exit 1
    echo
    echo "  versionCode $USED Play'da allaqachon bor (precheck ko'rmagan) — raqam oshirilib qayta build qilinadi..."
    PLAY_MAX="$USED"
    BUILD_NUM=$((USED + 1))
    SEMVER="$(version_from_code "$BUILD_NUM")"
    TARGET="${SEMVER}+${BUILD_NUM}"
    sed -i '' "s/^version: .*/version: ${TARGET}/" pubspec.yaml
    echo "Versiya: -> $TARGET"
    build_aab
    upload_to_play
elif [ "$UP_RC" -ne 0 ]; then
    exit "$UP_RC"
fi
