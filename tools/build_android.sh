#!/usr/bin/env bash
# Stop immediately on command errors, unset variables, or failed pipeline stages.
set -euo pipefail

# Resolve the repository root so every build path is independent of the caller's directory.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Allow CI or local toolchains to override these defaults without editing the script.
GODOT_BIN="${GODOT_BIN:-$ROOT/tools/Godot_v4.7.2-stable_win64_console.exe}"
ANDROID_SDK="${ANDROID_SDK:-C:/Users/Yasamin/.evolab-toolchain/sdk}"
JDK_HOME="${JDK_HOME:-C:/Users/Yasamin/.evolab-toolchain/jdk-21.0.13.1+2}"
BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$ANDROID_SDK/build-tools/36.0.0}"

# Locate the Android packaging, signing, inspection, and JAR utilities.
ZIPALIGN="$BUILD_TOOLS/zipalign.exe"
APKSIGNER="$BUILD_TOOLS/apksigner.bat"
AAPT2="$BUILD_TOOLS/aapt2.exe"
JAR="$JDK_HOME/bin/jar.exe"

# Keep local signing material separate from generated distributable artifacts.
DEBUG_KEYSTORE="$ROOT/builds/keystore/debug.keystore"
RELEASE_KEYSTORE="$ROOT/builds/keystore/release.keystore"
RELEASE_PASSWORD_FILE="$ROOT/builds/keystore/release-password.txt"
OUTPUT_DIR="$ROOT/builds/android"
RESULT_DIR="$ROOT/builds/test-results"
ICON_PATCH_ROOT="$OUTPUT_DIR/.icon-fix"
ICON_PATCH_FILE="$ICON_PATCH_ROOT/res/mipmap-anydpi-v26/themed_icon.xml"

# Fail before export if any required build executable is unavailable.
for tool in "$GODOT_BIN" "$ZIPALIGN" "$APKSIGNER" "$AAPT2" "$JAR"; do
  if [[ ! -f "$tool" ]]; then
    printf 'Missing build tool: %s\n' "$tool" >&2
    exit 1
  fi
done
# Fail early when local signing material is missing, without printing its contents.
for file in "$DEBUG_KEYSTORE" "$RELEASE_KEYSTORE" "$RELEASE_PASSWORD_FILE"; do
  if [[ ! -f "$file" ]]; then
    printf 'Missing signing file: %s\n' "$file" >&2
    exit 1
  fi
done
if ! command -v unzip >/dev/null 2>&1; then
  printf 'Missing build tool: unzip\n' >&2
  exit 1
fi

# Prepare APK output, verification reports, and the temporary icon-patch tree.
mkdir -p "$OUTPUT_DIR" "$RESULT_DIR" "$(dirname "$ICON_PATCH_FILE")"

# Reimport assets so both export variants use the current Godot import cache.
printf 'Reimporting Godot project...\n'
"$GODOT_BIN" --headless --path "$ROOT" --editor --import --quit

# Require every gameplay sound effect to have a successful Godot import.
sfx_names=(birds click grow harvest plant prepare quiz_correct quiz_wrong rain save steps unlock water water_loop wind)
for name in "${sfx_names[@]}"; do
  if ! compgen -G ".godot/imported/sfx_${name}.wav-*.sample" >/dev/null; then
    printf 'Missing imported audio resource: sfx_%s.wav\n' "$name" >&2
    exit 1
  fi
done
# Require every user-supplied music track to be imported before packaging.
for name in garden path rain title; do
  if ! compgen -G ".godot/imported/music_${name}.mp3-*.mp3str" >/dev/null; then
    printf 'Missing imported music resource: music_%s.mp3\n' "$name" >&2
    exit 1
  fi
done

# Run the full regression suite before producing any distributable package.
printf 'Running Godot regression suite...\n'
"$GODOT_BIN" --headless --path "$ROOT" --scene res://tests/test_runner.tscn

# Export debug and release APKs as unsigned packages for the signing stage.
printf 'Exporting Android debug and release APKs...\n'
"$GODOT_BIN" --headless --path "$ROOT" --export-debug "Android Debug" "$OUTPUT_DIR/roots-of-sacrifice-debug-unsigned.apk"
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Android Release" "$OUTPUT_DIR/roots-of-sacrifice-release-unsigned.apk"

# Add Android 13 themed-icon metadata by reusing the packaged launcher icon.
patch_themed_icon() {
  local apk="$1"
  unzip -p "$apk" res/mipmap-anydpi-v26/icon.xml > "$ICON_PATCH_FILE"
  "$JAR" uf "$apk" -C "$ICON_PATCH_ROOT" res/mipmap-anydpi-v26/themed_icon.xml
}

# Patch both unsigned packages before alignment and signing invalidate their offsets.
patch_themed_icon "$OUTPUT_DIR/roots-of-sacrifice-debug-unsigned.apk"
patch_themed_icon "$OUTPUT_DIR/roots-of-sacrifice-release-unsigned.apk"

# Align the debug package, then sign it with the standard local debug key.
printf 'Aligning and signing APKs...\n'
"$ZIPALIGN" -p -f 4 "$OUTPUT_DIR/roots-of-sacrifice-debug-unsigned.apk" "$OUTPUT_DIR/roots-of-sacrifice-debug-aligned.apk"
"$APKSIGNER" sign \
  --ks "$DEBUG_KEYSTORE" \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$OUTPUT_DIR/roots-of-sacrifice-debug.apk" \
  "$OUTPUT_DIR/roots-of-sacrifice-debug-aligned.apk"

# Align the release package before applying its private signing credentials.
"$ZIPALIGN" -p -f 4 "$OUTPUT_DIR/roots-of-sacrifice-release-unsigned.apk" "$OUTPUT_DIR/roots-of-sacrifice-release-aligned.apk"
# Pass the release password through the environment rather than command arguments.
ROOTS_KEYSTORE_PASSWORD="$(< "$RELEASE_PASSWORD_FILE")"
export ROOTS_KEYSTORE_PASSWORD
"$APKSIGNER" sign \
  --ks "$RELEASE_KEYSTORE" \
  --ks-key-alias roots_of_sacrifice \
  --ks-pass env:ROOTS_KEYSTORE_PASSWORD \
  --key-pass env:ROOTS_KEYSTORE_PASSWORD \
  --out "$OUTPUT_DIR/roots-of-sacrifice-release.apk" \
  "$OUTPUT_DIR/roots-of-sacrifice-release-aligned.apk"
# Remove the signing password from the environment immediately after use.
unset ROOTS_KEYSTORE_PASSWORD

# Verify integrity, signatures, packaged resources, metadata, and permissions.
verify_apk() {
  local apk="$1"
  local name="$2"
  local badging_file="$RESULT_DIR/$name-badging.txt"
  local permissions_file="$RESULT_DIR/$name-permissions.txt"
  local badging
  local permissions
  local listing
  local themed_icon
  local required

  # Check archive alignment and validate the APK signing certificate.
  "$ZIPALIGN" -c -p 4 "$apk"
  "$APKSIGNER" verify --verbose --print-certs "$apk"
  # Persist package metadata and permission reports for build auditing.
  "$AAPT2" dump badging "$apk" > "$badging_file"
  "$AAPT2" dump permissions "$apk" > "$permissions_file"
  badging="$(< "$badging_file")"
  permissions="$(< "$permissions_file")"
  listing="$(unzip -Z1 "$apk")"
  themed_icon="$("$AAPT2" dump xmltree "$apk" --file res/mipmap-anydpi-v26/themed_icon.xml)"

  # Ensure the runtime pack, scripts, and adaptive-icon parts are present.
  for required in assets/assets.sparsepck assets/scripts/main.gdc res/mipmap-anydpi-v26/icon.xml res/mipmap-anydpi-v26/themed_icon.xml; do
    if [[ "$listing" != *"$required"* ]]; then
      printf 'Missing packaged resource %s in %s\n' "$required" "$apk" >&2
      exit 1
    fi
  done
  # Reject development scratch files that must never ship in a release package.
  if [[ "$listing" == *".character-art-before.json"* ]]; then
    printf 'Unexpected development scratch file in %s\n' "$apk" >&2
    exit 1
  fi
  if [[ "$themed_icon" != *"monochrome"* ]]; then
    printf 'Themed icon does not reference the monochrome asset in %s\n' "$apk" >&2
    exit 1
  fi
  if [[ "$badging" != *"package: name='ir.roots_of_sacrifice.game' versionCode='1' versionName='1.0.0'"* ]]; then
    printf 'Unexpected package metadata in %s\n' "$apk" >&2
    exit 1
  fi
  if [[ "$badging" != *"minSdkVersion:'24'"* || "$badging" != *"targetSdkVersion:'36'"* ]]; then
    printf 'Unexpected Android SDK range in %s\n' "$apk" >&2
    exit 1
  fi
  if [[ "$badging" != *"uses-gl-es: '0x30000'"* ]]; then
    printf 'Expected GLES3 requirement missing from %s\n' "$apk" >&2
    exit 1
  fi
  if [[ "$badging" != *"native-code: 'arm64-v8a' 'armeabi-v7a'"* ]]; then
    printf 'Unexpected ABI set in %s\n' "$apk" >&2
    exit 1
  fi
  # Enforce the offline security requirement by rejecting every declared permission.
  if [[ "$permissions" == *"android.permission.INTERNET"* || "$permissions" == *"uses-permission"* ]]; then
    printf 'Unexpected Android permission found in %s\n' "$apk" >&2
    exit 1
  fi
}

# Run the full verification suite against both final signed packages.
printf 'Verifying final APKs...\n'
verify_apk "$OUTPUT_DIR/roots-of-sacrifice-debug.apk" android-debug
verify_apk "$OUTPUT_DIR/roots-of-sacrifice-release.apk" android-release
# Record checksums so distributed APKs can be compared against these build results.
sha256sum "$OUTPUT_DIR/roots-of-sacrifice-debug.apk" "$OUTPUT_DIR/roots-of-sacrifice-release.apk" > "$RESULT_DIR/android-sha256.txt"

printf 'Android build complete:\n'
printf '  %s\n' "$OUTPUT_DIR/roots-of-sacrifice-debug.apk"
printf '  %s\n' "$OUTPUT_DIR/roots-of-sacrifice-release.apk"
