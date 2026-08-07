#!/usr/bin/env bash
#
# Mone — Android build va Google Play'ga avtomatik yuklash (test uchun).
# Finder'da ikki marta bosib ham, terminaldan ham ishlatsa bo'ladi.
#
#   ./deploy_play.command                  versiya + build raqamini oshiradi va internal testga yuboradi
#   ./deploy_play.command --minor          o'rta raqam  (0.6.8+68 -> 0.7.0+69)
#   ./deploy_play.command --major          bosh raqam   (0.6.8+68 -> 1.0.0+69)
#   ./deploy_play.command --build          faqat build raqami (versiya o'zgarmaydi)
#   ./deploy_play.command --version 1.3.0  versiyani qo'lda belgilash (build +1 bo'ladi)
#   ./deploy_play.command --no-bump        hech nimaga tegmaydi (aynan shu build'ni qayta yuklash)
#   ./deploy_play.command --track beta     boshqa track (internal|alpha|beta|production)
#   ./deploy_play.command --notes "matn"   testerlarga ko'rinadigan izoh
#   ./deploy_play.command --validate       yuklamaydi, faqat Play tekshiruvidan o'tkazadi
#   ./deploy_play.command --clean          flutter keshini tozalab build qiladi
#
# Nima bo'ladi: AAB build qilinadi -> Play'ga yuklanadi -> `internal` (Internal testing)
# trackda status `completed` bilan e'lon qilinadi -> commit. Ya'ni testerlar ro'yxatidagi
# odamlarga Play Store'da yangilanish O'ZI chiqadi, qo'lda hech narsa bosish shart emas.
#
# Testerlar ro'yxati BIR MARTA Play Console'da sozlanadi:
#   Play Console -> Testing -> Internal testing -> Testers -> email ro'yxati (yoki Google guruh),
#   keyin "Copy link" — testerlar shu link orqali bir marta qo'shiladi (opt-in).
# Shundan keyin har bir yuklash avtomat o'sha odamlarga boradi.
#
# Versiya (0.6.8) = Play'da ko'rinadigan raqam, build (+68) = versionCode. Play bir xil
# versionCode'ni ikkinchi marta qabul qilmaydi va u doim o'sishi shart — shuning uchun
# skript Play'dagi eng katta versionCode'ni tekshirib, kerak bo'lsa undan yuqori qilib oladi.
#
# Konfiguratsiya: ~/.mone_play.env (bo'lmasa ~/.sadinov_play.env ishlatiladi):
#   PLAY_SA_JSON=$HOME/.playconsole/mone-service-account.json
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
    rm -f "${PRECHECK_PY:-}"
    if [ -t 0 ]; then
        echo
        [ $code -eq 0 ] || echo "[XATO] Skript $code kodi bilan tugadi."
        read -r -p "Yopish uchun Enter bosing..."
    fi
}
PRECHECK_PY=""
trap cleanup_and_pause EXIT

# Finder'dan ochilganda PATH'da flutter bo'lmasligi mumkin — zsh login PATH'idan topamiz
if ! command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(/bin/zsh -lc 'command -v flutter' 2>/dev/null || true)"
    [ -n "$FLUTTER_BIN" ] && PATH="$(dirname "$FLUTTER_BIN"):$PATH"
fi
command -v flutter >/dev/null 2>&1 || { echo "flutter topilmadi (PATH)." >&2; exit 1; }

BUMP=patch          # patch | minor | major | build | none
VALIDATE=0
CLEAN=0
NEW_VERSION=""
TRACK="internal"
NOTES="${PLAY_NOTES:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --no-bump)            BUMP=none ;;
        --build|--build-only) BUMP=build ;;
        --patch)              BUMP=patch ;;
        --minor)              BUMP=minor ;;
        --major)              BUMP=major ;;
        --validate) VALIDATE=1 ;;
        --clean)    CLEAN=1 ;;
        --version)  NEW_VERSION="${2:-}"; shift ;;
        --track)    TRACK="${2:-}"; shift ;;
        --notes)    NOTES="${2:-}"; shift ;;
        -h|--help)  awk 'NR>2 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
        *)          echo "Noma'lum parametr: $1"; exit 1 ;;
    esac
    shift
done

case "$TRACK" in
    internal|alpha|beta|production) ;;
    *) echo "Noto'g'ri track: $TRACK (internal|alpha|beta|production)" >&2; exit 1 ;;
esac

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

if [ ! -f "$PLAY_SA_JSON" ]; then
    echo "Service account JSON topilmadi: $PLAY_SA_JSON" >&2
    exit 1
fi

python3 -c "import googleapiclient, google.oauth2" 2>/dev/null || {
    echo "Python kutubxonalari yetishmayapti. O'rnating:" >&2
    echo "    python3 -m pip install google-api-python-client google-auth" >&2
    exit 1
}

PKG="$(sed -n 's/.*applicationId *= *"\(.*\)".*/\1/p' android/app/build.gradle 2>/dev/null | head -1)"
[ -n "$PKG" ] || { echo "applicationId topilmadi (android/app/build.gradle)." >&2; exit 1; }
echo "Ilova: $PKG"

# --- 2. Versiya ---
# Play'dagi eng katta versionCode'ni oldindan so'raymiz: shu bilan (a) auth/huquq xatosi
# 10 daqiqalik build'dan OLDIN chiqadi, (b) versionCode aniq o'sadi.

version_line() { grep '^version:' pubspec.yaml | head -1 | sed 's/^version: *//' | tr -d ' \r'; }

CURRENT="$(version_line)"
SEMVER="${CURRENT%%+*}"
BUILD_NUM="${CURRENT##*+}"

bump_semver() {
    local major minor patch
    IFS=. read -r major minor patch <<< "$1"
    major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}
    case "$2" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
    esac
    echo "${major}.${minor}.${patch}"
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

set +e
PLAY_MAX="$(SA_JSON="$PLAY_SA_JSON" PKG="$PKG" python3 "$PRECHECK_PY")"
PRECHECK_RC=$?
set -e

# Huquq / ilova topilmadi xatosi — 10 daqiqalik build'dan oldin to'xtaymiz.
# (`set -e` bor: shart bajarilmasa butun skript chiqib ketmasligi uchun `if` ishlatilgan,
#  `[ ... ] && exit` emas.)
if [ "$PRECHECK_RC" -eq 2 ]; then
    exit 1
fi

case "$PLAY_MAX" in
    ''|*[!0-9]*) echo "  (versionCode ro'yxatini olib bo'lmadi — lokal raqam ishlatiladi)"; PLAY_MAX=0 ;;
    *) echo "  Play'dagi eng katta versionCode: $PLAY_MAX" ;;
esac

[ -n "$NEW_VERSION" ] && SEMVER="$NEW_VERSION"

case "$BUMP" in
    major|minor|patch)
        [ -n "$NEW_VERSION" ] || SEMVER="$(bump_semver "$SEMVER" "$BUMP")"
        BUILD_NUM=$((BUILD_NUM + 1))
        ;;
    build) BUILD_NUM=$((BUILD_NUM + 1)) ;;
    none)  ;;
esac

# Play'da bor bo'lgan versionCode qayta qabul qilinmaydi — undan yuqoriga ko'taramiz
if [ "$BUMP" != "none" ] && [ "$BUILD_NUM" -le "$PLAY_MAX" ]; then
    BUILD_NUM=$((PLAY_MAX + 1))
    echo "  Build raqami Play'ga moslab ko'tarildi: $BUILD_NUM"
elif [ "$BUMP" = "none" ] && [ "$BUILD_NUM" -le "$PLAY_MAX" ] && [ "$VALIDATE" -eq 0 ]; then
    echo "  [OGOHLANTIRISH] versionCode $BUILD_NUM Play'da allaqachon bor — yuklash rad etiladi." >&2
fi

TARGET="${SEMVER}+${BUILD_NUM}"
if [ "$TARGET" != "$CURRENT" ]; then
    # macOS sed — .bak faylsiz o'zgartirish
    sed -i '' "s/^version: .*/version: ${TARGET}/" pubspec.yaml
    echo "Versiya: $CURRENT -> $TARGET"
else
    echo "Versiya: $TARGET (o'zgarmadi)"
fi

# --- 3. Build ---

if [ "$CLEAN" -eq 1 ]; then
    echo "Kesh tozalanmoqda..."
    flutter clean >/dev/null
fi

echo "AAB build qilinmoqda..."
flutter build appbundle --release

AAB="build/app/outputs/bundle/release/app-release.aab"
[ -f "$AAB" ] || { echo "AAB fayl topilmadi — build muvaffaqiyatsiz." >&2; exit 1; }
echo "AAB tayyor: $AAB ($(du -h "$AAB" | cut -f1))"

MAPPING="build/app/outputs/mapping/release/mapping.txt"

# --- 4. Google Play ---

if [ "$VALIDATE" -eq 1 ]; then
    echo "Google Play tekshiruvidan o'tkazilmoqda (validate)..."
else
    echo "Google Play'ga yuborilmoqda ($TRACK track)..."
fi

SA_JSON="$PLAY_SA_JSON" PKG="$PKG" AAB="$AAB" MAPPING="$MAPPING" \
TRACK="$TRACK" VALIDATE="$VALIDATE" RELEASE_NAME="$TARGET" NOTES="$NOTES" \
python3 - <<'PY'
import os, sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

sa_json  = os.environ["SA_JSON"]
pkg      = os.environ["PKG"]
aab      = os.environ["AAB"]
mapping  = os.environ["MAPPING"]
track    = os.environ["TRACK"]
validate = os.environ["VALIDATE"] == "1"
name     = os.environ["RELEASE_NAME"]
notes    = os.environ.get("NOTES", "").strip()

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

print("AAB yuklanmoqda...")
media = MediaFileUpload(aab, mimetype="application/octet-stream",
                        chunksize=8 * 1024 * 1024, resumable=True)
bundle = svc.edits().bundles().upload(
    packageName=pkg, editId=edit_id, media_body=media).execute(num_retries=5)
version_code = bundle["versionCode"]
print(f"Yuklandi: versionCode {version_code}")

if os.path.isfile(mapping):
    print("ProGuard mapping yuklanmoqda...")
    svc.edits().deobfuscationfiles().upload(
        packageName=pkg, editId=edit_id, apkVersionCode=version_code,
        deobfuscationFileType="proguard",
        media_body=MediaFileUpload(mapping, mimetype="application/octet-stream"),
    ).execute(num_retries=5)

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

svc.edits().tracks().update(
    packageName=pkg, editId=edit_id, track=track, body={"releases": [release]},
).execute()

if validate:
    svc.edits().validate(packageName=pkg, editId=edit_id).execute()
    print("Tekshiruvdan o'tdi (yuklanmadi).")
    sys.exit(0)

svc.edits().commit(packageName=pkg, editId=edit_id).execute()
print(f"Tayyor — build {name} '{track}' trackda e'lon qilindi.")

if track == "internal":
    print("Testerlarga bir necha daqiqada Play Store'da yangilanish chiqadi.")
    print("Testerlar ro'yxati: Play Console -> Testing -> Internal testing -> Testers.")
PY
