#!/usr/bin/env bash
# بناء «البيان» لـ iOS ورفعه إلى TestFlight — نفس طريقة «وصل» الناجحة:
# أرشفة بدون توقيع، ثم توقيع للتوزيع وقت التصدير عبر مفتاح App Store Connect.
# السر الوحيد المطلوب في المستودع: APP_STORE_CONNECT_KEY (محتوى ملف .p8 كاملًا)
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="5V6TC85KRL"
BUNDLE_ID="sa.almubarky.albayan"
DEFAULT_ISSUER="3aa57344-99da-4421-94f9-5aaf95c16287"
DEFAULT_KEY_ID="Y6PW89YX6J"   # مفتاح «قطعة سيارتك» — نفس الفريق
LOG=/tmp/albayan-ci.log
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

# ── يُرفع آخر سجل إلى فرع ci-logs ليقرأه Claude مباشرة ──
report() {
  local code=$?
  set +e
  sleep 1
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    local extra url d
    extra=$(git -C "$GITHUB_WORKSPACE" config --get http.https://github.com/.extraheader)
    url=$(git -C "$GITHUB_WORKSPACE" remote get-url origin)
    d=$(mktemp -d)
    tail -n 800 "$LOG" > "$d/last-ios.log"
    echo "run=${GITHUB_RUN_NUMBER:-?} exit=$code $(date -u '+%Y-%m-%d %H:%M UTC')" > "$d/status.txt"
    (
      cd "$d" && git init -q && git checkout -q -b ci-logs && git add . &&
      git -c user.name=albayan-ci -c user.email=ci@albayan.local commit -qm "iOS run ${GITHUB_RUN_NUMBER:-?} exit $code" &&
      git -c http.https://github.com/.extraheader="$extra" push -qf "$url" ci-logs
    ) || echo "⚠️ تعذّر رفع السجل"
  fi
  exit $code
}
trap report EXIT

step() { echo; echo "==================== $* ===================="; }

step "Xcode"
XC=$(ls -d /Applications/Xcode_26* 2>/dev/null | sort -V | tail -1 || true)
if [ -n "$XC" ]; then sudo xcode-select -s "$XC/Contents/Developer"; fi
xcodebuild -version

step "مفتاح App Store Connect"
if [ -z "${APP_STORE_CONNECT_KEY:-}" ]; then
  echo "❌ السر APP_STORE_CONNECT_KEY غير موجود في إعدادات المستودع (Settings ← Secrets ← Actions)"
  exit 1
fi
KEY_ID=$(printf '%s' "${APP_STORE_CONNECT_KEY_ID:-$DEFAULT_KEY_ID}" | tr -d '[:space:]')
ISSUER=$(printf '%s' "${APP_STORE_CONNECT_ISSUER_ID:-$DEFAULT_ISSUER}" | tr -d '[:space:]')
[ -n "$KEY_ID" ] || KEY_ID="$DEFAULT_KEY_ID"
[ -n "$ISSUER" ] || ISSUER="$DEFAULT_ISSUER"
echo "Key ID: $KEY_ID"
mkdir -p "$HOME/private_keys"
KEY_PATH="$HOME/private_keys/AuthKey_${KEY_ID}.p8"
printf '%s\n' "$APP_STORE_CONNECT_KEY" > "$KEY_PATH"
grep -q "BEGIN PRIVATE KEY" "$KEY_PATH" || { echo "❌ APP_STORE_CONNECT_KEY لازم يكون محتوى ملف .p8 كامل مع سطري BEGIN و END"; exit 1; }
grep -q "END PRIVATE KEY" "$KEY_PATH" || { echo "❌ APP_STORE_CONNECT_KEY ناقص — سطر END PRIVATE KEY غير موجود"; exit 1; }
echo "✅ المفتاح سليم"
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$KEY_ID"
      -authenticationKeyIssuerID "$ISSUER")

step "أدوات بايثون"
python3 -m pip install -q --break-system-packages fonttools pillow pyjwt cryptography 2>/dev/null \
  || python3 -m pip install -q fonttools pillow pyjwt cryptography

step "حساب Apple: معرّف التطبيق وسجل التطبيق"
ASC_KEY_PATH="$KEY_PATH" ASC_KEY_ID="$KEY_ID" ASC_ISSUER="$ISSUER" BUNDLE_ID="$BUNDLE_ID" \
  python3 tool/asc.py

step "بيانات المصحف والمتشابهات"
python3 tool/build_data.py

step "مشروع iOS"
if [ ! -d ios/Runner ]; then
  flutter create --org sa.almubarky --project-name albayan --platforms=ios . > /tmp/flutter_create.log
  tail -3 /tmp/flutter_create.log
fi
python3 tool/apply_icons.py ios

step "الحزم وتحليل الكود"
flutter pub get > /tmp/pub.log 2>&1 || { cat /tmp/pub.log; exit 1; }
flutter analyze --no-fatal-infos --no-fatal-warnings > /tmp/analyze.log 2>&1 || { cat /tmp/analyze.log; echo "❌ أخطاء في الكود"; exit 1; }
tail -1 /tmp/analyze.log

step "Info.plist"
P=ios/Runner/Info.plist
pset() {
  /usr/libexec/PlistBuddy -c "Delete :$1" "$P" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :$1 $2 $3" "$P"
}
pset CFBundleDisplayName string "البيان"
pset CFBundleDevelopmentRegion string "ar"
pset ITSAppUsesNonExemptEncryption bool false
/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$P"

BUILD=$(( 100 + ${GITHUB_RUN_NUMBER:-1} ))
step "بناء Flutter (رقم البناء $BUILD)"
APP_STORE_ID=$(cat build/app_store_id.txt 2>/dev/null || true)
echo "رقم التطبيق في المتجر: ${APP_STORE_ID:-غير معروف}"
flutter build ios --release --no-codesign --build-number=$BUILD --dart-define=APP_STORE_ID=$APP_STORE_ID

step "الأرشفة (بدون توقيع — التوقيع وقت التصدير)"
xcodebuild -quiet \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Runner.xcarchive \
  archive \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

step "التوقيع للتوزيع والرفع إلى TestFlight"
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
# خوادم Apple تتعثر أحيانًا ("Error Downloading App Information")؛ نعيد المحاولة
ok=0
for attempt in 1 2 3 4; do
  if xcodebuild -exportArchive \
      -archivePath build/Runner.xcarchive \
      -exportOptionsPlist build/ExportOptions.plist \
      -exportPath build/export \
      "${AUTH[@]}"; then ok=1; break; fi
  echo "⚠️ محاولة الرفع $attempt فشلت — تفاصيل سجل التوزيع:"
  L=$(ls -td "${TMPDIR:-/tmp}"/*.xcdistributionlogs 2>/dev/null | head -1)
  [ -n "$L" ] && grep -hiE "error|fail|status|http" "$L"/*.log 2>/dev/null | tail -25
  sleep $((attempt * 60))
done
[ "$ok" = 1 ] || { echo "❌ فشل الرفع بعد عدة محاولات"; exit 70; }

step "✅ اكتمل — النسخة $BUILD مرفوعة إلى TestFlight (تظهر خلال ١٠–٢٠ دقيقة)"
