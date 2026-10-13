#!/bin/zsh
# Local Developer ID candidate only. No GitHub publication or App Store upload.
set -euo pipefail
reference_repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$reference_repo"
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  print -u2 'Commit intended source and leave a clean checkout before packaging.'; exit 1
fi
: "${REFERENCE_SIGNING_IDENTITY:?Set the exact verified Developer ID Application fingerprint}"
: "${REFERENCE_NOTARY_PROFILE:?Set an existing approved notarytool Keychain profile}"
reference_commit="$(git rev-parse HEAD)"
reference_output="${REFERENCE_RELEASE_DIR:-$reference_repo/../../artifacts/reference/$reference_commit}"
reference_build="${REFERENCE_RELEASE_BUILD_DIR:-/private/tmp/reference-release-$reference_commit}"
mkdir -p "$reference_output"
cd "$reference_repo/macos"
xcodebuild build -project Snapwell.xcodeproj -scheme Snapwell -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$reference_build" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO
reference_app="$reference_output/Vaultline Reference.app"
if [[ -e "$reference_app" ]]; then print -u2 'Candidate already exists; use a fresh output directory.'; exit 1; fi
/usr/bin/ditto "$reference_build/Build/Products/Release/Snapwell.app" "$reference_app"
/usr/libexec/PlistBuddy -c "Add :ReferenceSourceCommit string $reference_commit" "$reference_app/Contents/Info.plist"
reference_entitlements="$reference_output/signing-entitlements.plist"
cat > "$reference_entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
</dict></plist>
PLIST
/usr/bin/codesign --force --options runtime --timestamp --sign "$REFERENCE_SIGNING_IDENTITY" --entitlements "$reference_entitlements" "$reference_app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$reference_app"
reference_archive="$reference_output/notarization-upload.zip"
/usr/bin/ditto -c -k --keepParent "$reference_app" "$reference_archive"
/usr/bin/xcrun notarytool submit "$reference_archive" --keychain-profile "$REFERENCE_NOTARY_PROFILE" --wait --output-format json > "$reference_output/notarization.json"
python3 - "$reference_output/notarization.json" <<'PY'
import json,sys
value=json.load(open(sys.argv[1]))
if value.get('status')!='Accepted':raise SystemExit('Notarization did not accept the candidate; do not distribute it.')
PY
/usr/bin/xcrun stapler staple "$reference_app"
/usr/bin/xcrun stapler validate "$reference_app"
/usr/sbin/spctl --assess --type execute --verbose=2 "$reference_app"
cd "$reference_repo"
git archive --format=tar --prefix=Vaultline-Reference-source/ "$reference_commit" | gzip > "$reference_output/Vaultline-Reference-source-$reference_commit.tar.gz"
reference_dmg_root="$reference_output/dmg-root"
mkdir -p "$reference_dmg_root"
/usr/bin/ditto "$reference_app" "$reference_dmg_root/Vaultline Reference.app"
ln -s /Applications "$reference_dmg_root/Applications"
cp "$reference_repo/LICENSE" "$reference_repo/COPYING" "$reference_dmg_root/"
cp "$reference_output/Vaultline-Reference-source-$reference_commit.tar.gz" "$reference_dmg_root/"
reference_dmg="$reference_output/Vaultline-Reference-$reference_commit.dmg"
/usr/bin/hdiutil create -volname 'Vaultline Reference' -srcfolder "$reference_dmg_root" -format UDZO "$reference_dmg"
/usr/bin/codesign --sign "$REFERENCE_SIGNING_IDENTITY" --timestamp "$reference_dmg"
/usr/bin/xcrun notarytool submit "$reference_dmg" --keychain-profile "$REFERENCE_NOTARY_PROFILE" --wait --output-format json > "$reference_output/dmg-notarization.json"
python3 - "$reference_output/dmg-notarization.json" <<'PYNOTARY'
import json,sys
if json.load(open(sys.argv[1])).get('status')!='Accepted':raise SystemExit('Disk image notarization did not accept the candidate.')
PYNOTARY
/usr/bin/xcrun stapler staple "$reference_dmg"
/usr/bin/xcrun stapler validate "$reference_dmg"
python3 - "$reference_output" "$reference_commit" "$reference_dmg" <<'PY'
import hashlib,json,pathlib,sys,plistlib
root=pathlib.Path(sys.argv[1]);info=plistlib.loads((root/'Vaultline Reference.app/Contents/Info.plist').read_bytes())
files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.iterdir() if p.is_file() and (p.suffix in {'.dmg','.gz'})}
manifest={'product':'Vaultline Reference','sourceCommit':sys.argv[2],'bundleId':info['CFBundleIdentifier'],'marketingVersion':info['CFBundleShortVersionString'],'buildNumber':info['CFBundleVersion'],'notarization':{'application':json.loads((root/'notarization.json').read_text()),'diskImage':json.loads((root/'dmg-notarization.json').read_text())},'sha256':files,'scope':'Local signed and notarized Mac candidate. No public binary publication. Exact corresponding source is included alongside the application.'}
(root/'release.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
print('Candidate and corresponding source:',str(root))
PY
