#!/usr/bin/env bash
#
# Mone — iOS build, App Store Connect'ga yuklash va TestFlight'ga AVTOMAT tarqatish.
# Finder'da ikki marta bosib ham, terminaldan ham ishlatsa bo'ladi.
#
#   ./deploy_ios.command                   HAMMASI: build -> yuklash -> TestFlight guruhlariga
#   ./deploy_ios.command --bump            versiyani majburan oshiradi (0.7.0+70 -> 0.7.1+71)
#   ./deploy_ios.command --minor           keyingi o'nlik (0.6.5+65 -> 0.7.0+70)
#   ./deploy_ios.command --major           keyingi yuzlik (0.6.5+65 -> 1.0.0+100)
#   ./deploy_ios.command --version 1.3.0   versiyani qo'lda belgilash (kod 130 bo'ladi)
#   ./deploy_ios.command --no-bump         aynan pubspec'dagi versiyani yuklash
#   ./deploy_ios.command --groups "A,B"    faqat shu TestFlight guruhlariga
#   ./deploy_ios.command --notes "matn"    "What to Test" izohi
#   ./deploy_ios.command --no-wait         yuklab qo'yadi, TestFlight tarqatishni kutmaydi
#   ./deploy_ios.command --validate        yuklamaydi, faqat App Store tekshiruvidan o'tkazadi
#   ./deploy_ios.command --clean           Xcode keshini tozalab build qiladi
#
# Nima bo'ladi (parametrsiz):
#   1. Versiya aniqlanadi (pubspec'daginisi App Store Connect'da band bo'lsa — oshiriladi)
#   2. `flutter build ipa --release`
#   3. `xcrun altool --upload-app` bilan App Store Connect'ga yuklanadi
#   4. Build "PROCESSING" dan "VALID" ga o'tguncha kutiladi (odatda 5-15 daqiqa)
#   5. Export compliance (shifrlash) javobi avtomat qo'yiladi — bo'lmasa TestFlight
#      "Missing Compliance" deb turib qoladi
#   6. "What to Test" izohi yoziladi
#   7. Build TestFlight guruhlariga qo'shiladi -> testerlarga xabar O'ZI boradi
#      (tashqi/external guruh bo'lsa beta review'ga ham o'zi yuboriladi)
#
# VERSIYA QOIDASI (Android tomoni bilan bir xil): versiya raqami = build raqami raqamlari:
#   0.6.8+68 -> 0.6.9+69 -> 0.7.0+70 -> 0.7.1+71 ... 0.9.9+99 -> 1.0.0+100
# Standart holatda pubspec'dagi raqam App Store Connect'da hali yo'q bo'lsa — AYNAN o'sha
# ishlatiladi. Shuning uchun avval Android (deploy_play.command), keyin iOS ishga tushirilsa,
# ikkala do'konda ham bir xil versiya chiqadi.
#
# Konfiguratsiya: ~/.mone_appstore.env (bo'lmasa ~/.sadinov_appstore.env — bitta Apple jamoasi):
#   ASC_KEY_ID=XXXXXXXXXX
#   ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# Kalit fayl: ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8
#
# Key ID va Issuer ID: App Store Connect -> Users and Access -> Integrations
# -> App Store Connect API. Kalitga kamida "App Manager" huquqi kerak.

set -euo pipefail

cd "$(dirname "$0")"

# Finder'dan (ikki bosish) ochilganda oynani natija bilan ochiq qoldirish
cleanup_and_pause() {
    local code=$?
    rm -f "${ASC_PY:-}"
    if [ -t 0 ]; then
        echo
        [ $code -eq 0 ] || echo "[XATO] Skript $code kodi bilan tugadi."
        read -r -p "Yopish uchun Enter bosing..."
    fi
}
ASC_PY=""
trap cleanup_and_pause EXIT

# Finder'dan ochilganda PATH faqat /usr/bin:/bin:/usr/sbin:/sbin bo'ladi — flutter u yerda yo'q.
# MUHIM: `zsh -lc` ~/.zshrc ni O'QIMAYDI (u faqat interaktiv shellda o'qiladi), `-i` kerak.
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
NO_WAIT=0
NEW_VERSION=""
GROUPS=""
NOTES="${ASC_NOTES:-}"
WAIT_MIN="${ASC_WAIT_MIN:-30}"

while [ $# -gt 0 ]; do
    case "$1" in
        --bump|--patch) BUMP=force ;;
        --minor)        BUMP=minor ;;
        --major)        BUMP=major ;;
        --no-bump)      BUMP=none ;;
        --no-wait)  NO_WAIT=1 ;;
        --validate) VALIDATE=1 ;;
        --clean)    CLEAN=1 ;;
        --version)  NEW_VERSION="${2:-}"; shift ;;
        --groups)   GROUPS="${2:-}"; shift ;;
        --notes)    NOTES="${2:-}"; shift ;;
        -h|--help)  awk 'NR>2 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
        *)          echo "Noma'lum parametr: $1"; exit 1 ;;
    esac
    shift
done

# --- 1. Konfiguratsiya ---

CONFIG="${ASC_CONFIG:-}"
if [ -z "$CONFIG" ]; then
    for c in "$HOME/.mone_appstore.env" "$HOME/.sadinov_appstore.env"; do
        [ -f "$c" ] && CONFIG="$c" && break
    done
fi
if [ -z "$CONFIG" ] || [ ! -f "$CONFIG" ]; then
    cat >&2 <<EOF
Konfiguratsiya topilmadi.

Quyidagicha yarating:
    cat > $HOME/.mone_appstore.env <<'CONF'
    ASC_KEY_ID=XXXXXXXXXX
    ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    CONF
    chmod 600 $HOME/.mone_appstore.env

Key ID va Issuer ID: App Store Connect -> Users and Access -> Integrations
-> App Store Connect API sahifasida.
EOF
    exit 1
fi
echo "Konfiguratsiya: $CONFIG"

# shellcheck disable=SC1090
source "$CONFIG"

: "${ASC_KEY_ID:?$CONFIG ichida ASC_KEY_ID yo'q}"
: "${ASC_ISSUER_ID:?$CONFIG ichida ASC_ISSUER_ID yo'q}"

KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
if [ ! -f "$KEY_FILE" ]; then
    echo "Kalit fayl topilmadi: $KEY_FILE" >&2
    echo "AuthKey_${ASC_KEY_ID}.p8 faylini o'sha joyga nusxalang." >&2
    exit 1
fi

# Kerakli kutubxonasi (cryptography) BOR python3 ni topamiz. Finder'dan ochilganda
# `python3` = Apple'niki bo'lib qoladi, unda kutubxona yo'q.
PY_BIN=""
for cand in "${ASC_PYTHON:-}" python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    [ -n "$cand" ] || continue
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "import cryptography" >/dev/null 2>&1; then
        PY_BIN="$cand"
        break
    fi
done
if [ -z "$PY_BIN" ]; then
    cand="$(/bin/zsh -ilc 'command -v python3' 2>/dev/null | tail -1 || true)"
    if [ -n "$cand" ] && "$cand" -c "import cryptography" >/dev/null 2>&1; then
        PY_BIN="$cand"
    fi
fi
if [ -z "$PY_BIN" ]; then
    echo "cryptography kutubxonasi bor python3 topilmadi. O'rnating:" >&2
    echo "    python3 -m pip install cryptography" >&2
    exit 1
fi

BUNDLE_ID="$(sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = \([^;]*\);.*/\1/p' ios/Runner.xcodeproj/project.pbxproj \
    | grep -v RunnerTests | head -1)"
[ -n "$BUNDLE_ID" ] || { echo "PRODUCT_BUNDLE_IDENTIFIER topilmadi." >&2; exit 1; }
echo "Ilova: $BUNDLE_ID"

# --- 2. App Store Connect yordamchisi ---
# Eslatma: bash 3.2 `$( ... <<HEREDOC ... )` ichidagi apostroflarni noto'g'ri o'qiydi,
# shuning uchun python alohida vaqtinchalik faylga yoziladi (trap uni o'chiradi).

ASC_PY="$(mktemp -t mone_asc).py"
cat > "$ASC_PY" <<'PY'
"""App Store Connect API yordamchisi: build raqamini bilish va TestFlight'ga tarqatish."""
import base64, json, os, sys, time, urllib.error, urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils as asym_utils

BASE = "https://api.appstoreconnect.apple.com"
KEY_FILE  = os.environ["ASC_KEY_FILE"]
KEY_ID    = os.environ["ASC_KEY_ID"]
ISSUER_ID = os.environ["ASC_ISSUER_ID"]
BUNDLE_ID = os.environ["BUNDLE_ID"]

_tok = {"value": None, "exp": 0}


def _b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def token():
    """ES256 JWT. PyJWT shart emas — cryptography bilan o'zimiz imzolaymiz."""
    now = int(time.time())
    if _tok["value"] and now < _tok["exp"] - 60:
        return _tok["value"]
    key = serialization.load_pem_private_key(open(KEY_FILE, "rb").read(), password=None)
    head = _b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    body = _b64(json.dumps({"iss": ISSUER_ID, "iat": now, "exp": now + 900,
                            "aud": "appstoreconnect-v1"}).encode())
    signing_input = head + b"." + body
    der = key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r, s = asym_utils.decode_dss_signature(der)
    sig = _b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    _tok["value"] = (signing_input + b"." + sig).decode()
    _tok["exp"] = now + 900
    return _tok["value"]


def api(path, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={
        "Authorization": "Bearer " + token(),
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise SystemExit(f"App Store Connect xatosi {e.code} ({method} {path}):\n{detail[:600]}")


def app_id():
    data = api(f"/v1/apps?filter[bundleId]={BUNDLE_ID}&limit=1").get("data", [])
    if not data:
        raise SystemExit(f"App Store Connect'da {BUNDLE_ID} topilmadi (kalit huquqini tekshiring).")
    return data[0]["id"]


def max_build(app):
    """Eng katta build raqami (hamma versiyalar bo'yicha)."""
    codes = [0]
    data = api(f"/v1/builds?filter[app]={app}&limit=200&sort=-uploadedDate").get("data", [])
    for b in data:
        try:
            codes.append(int(b["attributes"]["version"]))
        except (TypeError, ValueError):
            pass
    return max(codes)


def find_build(app, version, build_number, timeout_min):
    """Build App Store Connect'da paydo bo'lib, PROCESSING dan chiqishini kutamiz."""
    deadline = time.time() + timeout_min * 60
    shown = None
    while True:
        found = api(f"/v1/builds?filter[app]={app}"
                    f"&filter[preReleaseVersion.version]={version}"
                    f"&filter[version]={build_number}&limit=1").get("data", [])
        if found:
            state = found[0]["attributes"]["processingState"]
            if state != shown:
                print(f"  build holati: {state}", flush=True)
                shown = state
            if state == "VALID":
                return found[0]
            if state in ("FAILED", "INVALID"):
                raise SystemExit(f"Build qayta ishlashda rad etildi: {state}. "
                                 "App Store Connect'dagi xat/xabarni tekshiring.")
        elif shown is None:
            print("  build hali ko'rinmadi, kutilmoqda...", flush=True)
            shown = "kutish"
        if time.time() > deadline:
            raise SystemExit(f"{timeout_min} daqiqada build tayyor bo'lmadi. "
                             "Keyinroq --no-bump bilan qayta urinib ko'ring.")
        time.sleep(30)


def ensure_compliance(build):
    """Shifrlash (export compliance) javobi bo'lmasa TestFlight build'ni tarqatmaydi."""
    if build["attributes"].get("usesNonExemptEncryption") is None:
        print("  export compliance javobi qo'yilmoqda (shifrlash: yo'q)...", flush=True)
        api(f"/v1/builds/{build['id']}", "PATCH", {"data": {
            "type": "builds", "id": build["id"],
            "attributes": {"usesNonExemptEncryption": False},
        }})


def set_notes(build, notes):
    if not notes:
        return
    locs = api(f"/v1/builds/{build['id']}/betaBuildLocalizations?limit=50").get("data", [])
    if locs:
        for loc in locs:
            api(f"/v1/betaBuildLocalizations/{loc['id']}", "PATCH", {"data": {
                "type": "betaBuildLocalizations", "id": loc["id"],
                "attributes": {"whatsNew": notes},
            }})
    else:
        api("/v1/betaBuildLocalizations", "POST", {"data": {
            "type": "betaBuildLocalizations",
            "attributes": {"locale": "en-US", "whatsNew": notes},
            "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}},
        }})
    print("  'What to Test' izohi yozildi", flush=True)


def distribute(build, wanted):
    groups = api(f"/v1/apps/{app_id_cached}/betaGroups?limit=200").get("data", [])
    if wanted:
        names = [w.strip().lower() for w in wanted.split(",") if w.strip()]
        groups = [g for g in groups if g["attributes"]["name"].lower() in names]
        if not groups:
            raise SystemExit(f"Berilgan nom bo'yicha TestFlight guruhi topilmadi: {wanted}")
    if not groups:
        print("  [OGOHLANTIRISH] TestFlight guruhi yo'q — App Store Connect -> TestFlight ->")
        print("                  Groups da guruh yaratib, testerlarni qo'shing.", flush=True)
        return
    external = False
    for g in groups:
        name = g["attributes"]["name"]
        api(f"/v1/betaGroups/{g['id']}/relationships/builds", "POST",
            {"data": [{"type": "builds", "id": build["id"]}]})
        kind = "internal" if g["attributes"].get("isInternalGroup") else "external"
        print(f"  guruhga qo'shildi: {name} ({kind})", flush=True)
        external = external or not g["attributes"].get("isInternalGroup")
    if external:
        # Tashqi testerlar uchun Apple beta review'i shart
        api("/v1/betaAppReviewSubmissions", "POST", {"data": {
            "type": "betaAppReviewSubmissions",
            "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}},
        }})
        print("  tashqi guruh uchun beta review'ga yuborildi", flush=True)


cmd = sys.argv[1]
app_id_cached = app_id()

if cmd == "maxbuild":
    print(max_build(app_id_cached))
elif cmd == "distribute":
    version, build_number, notes, wait_min = sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
    groups = sys.argv[6] if len(sys.argv) > 6 else ""
    print("Build App Store Connect'da qayta ishlanishi kutilmoqda...", flush=True)
    b = find_build(app_id_cached, version, build_number, wait_min)
    ensure_compliance(b)
    set_notes(b, notes)
    distribute(b, groups)
else:
    raise SystemExit(f"Noma'lum buyruq: {cmd}")
PY

asc() {
    ASC_KEY_FILE="$KEY_FILE" ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" \
    BUNDLE_ID="$BUNDLE_ID" "$PY_BIN" "$ASC_PY" "$@"
}

# --- 3. Versiya ---
# App Store Connect'dagi eng katta build raqamini oldindan so'raymiz: auth/huquq xatosi
# uzoq build'dan OLDIN chiqadi va raqam aniq o'sadi.

version_line() { grep '^version:' pubspec.yaml | head -1 | sed 's/^version: *//' | tr -d ' \r'; }

CURRENT="$(version_line)"
SEMVER="${CURRENT%%+*}"
BUILD_NUM="${CURRENT##*+}"

# Versiya raqami HAR DOIM build raqamining raqamlaridan tuziladi (Android bilan bir xil):
#   69 -> 0.6.9    70 -> 0.7.0    100 -> 1.0.0    1000 -> 10.0.0
version_from_code() {
    echo "$(($1 / 100)).$(($1 / 10 % 10)).$(($1 % 10))"
}

code_from_version() {
    local major minor patch
    IFS=. read -r major minor patch <<< "$1"
    major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}
    if [ "$minor" -gt 9 ] || [ "$patch" -gt 9 ]; then
        echo "Versiya raqamlari build raqami bilan bog'liq: o'rta va oxirgi bo'lak 0-9 bo'lishi kerak ($1)." >&2
        return 1
    fi
    echo $((major * 100 + minor * 10 + patch))
}

echo "App Store Connect'dagi mavjud build raqami tekshirilmoqda..."
set +e
ASC_MAX="$(asc maxbuild)"
ASC_RC=$?
set -e
if [ "$ASC_RC" -ne 0 ]; then
    echo "$ASC_MAX" >&2
    exit 1
fi
echo "  App Store Connect'dagi eng katta build: $ASC_MAX"

if [ -n "$NEW_VERSION" ]; then
    BUILD_NUM="$(code_from_version "$NEW_VERSION")" || exit 1
    if [ "$BUILD_NUM" -le "$ASC_MAX" ]; then
        echo "Versiya $NEW_VERSION -> build $BUILD_NUM, lekin App Store Connect'da $ASC_MAX bor." >&2
        echo "Kattaroq versiya bering (masalan $(version_from_code $((ASC_MAX + 1))))." >&2
        exit 1
    fi
else
    case "$BUMP" in
        # auto: pubspec'dagi raqam bo'sh bo'lsa AYNAN o'shani ishlatamiz (Android bilan
        # bir xil versiya chiqishi uchun), band bo'lsa keyingisiga o'tamiz
        auto)  [ "$BUILD_NUM" -le "$ASC_MAX" ] && BUILD_NUM=$((ASC_MAX + 1)) ;;
        force) BUILD_NUM=$(( (BUILD_NUM > ASC_MAX ? BUILD_NUM : ASC_MAX) + 1 )) ;;
        minor) BUILD_NUM=$(( ((BUILD_NUM > ASC_MAX ? BUILD_NUM : ASC_MAX) / 10 + 1) * 10 )) ;;
        major) BUILD_NUM=$(( ((BUILD_NUM > ASC_MAX ? BUILD_NUM : ASC_MAX) / 100 + 1) * 100 )) ;;
        none)  ;;
    esac
fi

if [ "$BUMP" = "none" ] && [ "$BUILD_NUM" -le "$ASC_MAX" ] && [ "$VALIDATE" -eq 0 ]; then
    echo "  [OGOHLANTIRISH] build $BUILD_NUM App Store Connect'da allaqachon bor — yuklash rad etiladi." >&2
fi

SEMVER="$(version_from_code "$BUILD_NUM")"
TARGET="${SEMVER}+${BUILD_NUM}"
if [ "$TARGET" != "$CURRENT" ]; then
    # macOS sed — .bak faylsiz o'zgartirish
    sed -i '' "s/^version: .*/version: ${TARGET}/" pubspec.yaml
    echo "Versiya: $CURRENT -> $TARGET"
else
    echo "Versiya: $TARGET (o'zgarmadi)"
fi

# --- 4. Build ---

if [ "$CLEAN" -eq 1 ]; then
    echo "Xcode keshi tozalanmoqda..."
    # Faqat shu loyihaning DerivedData katalogi (boshqa loyihalarga tegilmaydi)
    xcodebuild -project ios/Runner.xcodeproj -showBuildSettings 2>/dev/null \
        | awk '/BUILD_DIR = /{print $3}' | head -1 \
        | sed 's#/Build/Products##' \
        | xargs rm -rf
    flutter clean >/dev/null
fi

echo "IPA build qilinmoqda..."
flutter build ipa --release

ARCHIVE="build/ios/archive/Runner.xcarchive"
IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1)"

# flutter export xatosida ham 0 bilan chiqishi mumkin (masalan, Xcode'da hisob ulanmagan
# bo'lsa) va papkada oldingi IPA qolib ketadi. IPA yo'q yoki yangi archive'dan eski bo'lsa —
# ASC API kaliti bilan qayta export qilamiz (cloud signing, Xcode hisobisiz ham ishlaydi).
if [ -z "$IPA" ] || [ "$ARCHIVE" -nt "$IPA" ]; then
    echo "flutter export IPA yaratmadi — API kalit bilan export qilinmoqda..."
    TEAM_ID="$(sed -n 's/.*DEVELOPMENT_TEAM = \([A-Z0-9]\{10\}\);.*/\1/p' ios/Runner.xcodeproj/project.pbxproj | head -1)"
    PLIST="build/ios/ExportOptionsASC.plist"
    cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST_EOF
    rm -rf build/ios/ipa
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportPath build/ios/ipa \
        -exportOptionsPlist "$PLIST" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$KEY_FILE" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1)"
fi

[ -n "$IPA" ] || { echo "IPA fayl topilmadi — build muvaffaqiyatsiz." >&2; exit 1; }
echo "IPA tayyor: $IPA ($(du -h "$IPA" | cut -f1))"

# --- 5. App Store Connect'ga yuklash ---

ACTION="--upload-app"
[ "$VALIDATE" -eq 1 ] && ACTION="--validate-app"

echo "App Store Connect'ga yuborilmoqda (${ACTION#--})..."
xcrun altool $ACTION \
    --type ios \
    --file "$IPA" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

if [ "$VALIDATE" -eq 1 ]; then
    echo "Tekshiruvdan o'tdi (yuklanmadi)."
    exit 0
fi
echo "Yuklandi: $TARGET"

# --- 6. TestFlight ---

if [ "$NO_WAIT" -eq 1 ]; then
    echo "TestFlight tarqatish kutilmadi (--no-wait). Keyinroq shu buyruq bilan tarqatasiz:"
    echo "  ./deploy_ios.command --no-bump --no-wait   # (yuklashsiz tarqatish uchun emas)"
    exit 0
fi

asc distribute "$SEMVER" "$BUILD_NUM" "$NOTES" "$WAIT_MIN" "$GROUPS"

echo
echo "Tayyor — $TARGET TestFlight'da testerlarga tarqatildi."
