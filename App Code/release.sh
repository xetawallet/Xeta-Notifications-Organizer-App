#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_DIR="$ROOT_DIR/APK's"
TEST_DIR="$APK_DIR/Test"
PROD_DIR="$APK_DIR/To be Uploaded"
UPLOADED_DIR="$APK_DIR/Uploaded"
ANDROID_DIR="$ROOT_DIR/android"
KEY_PROPERTIES="$ANDROID_DIR/key.properties"
UPLOAD_KEYSTORE="$ANDROID_DIR/upload-keystore.jks"
UPLOAD_KEY_ALIAS="upload"

mkdir -p "$TEST_DIR" "$PROD_DIR" "$UPLOADED_DIR"

next_test_version() {
  local best_x=-1 best_y=-1 best_z=-1 file name x y z
  shopt -s nullglob
  for file in "$TEST_DIR"/test-v-*.apk; do
    name="$(basename "$file")"
    if [[ "$name" =~ ^test-v-([0-9]+)\.([0-9]+)\.([0-9]+)\.apk$ ]]; then
      x="${BASH_REMATCH[1]}"; y="${BASH_REMATCH[2]}"; z="${BASH_REMATCH[3]}"
      if (( x > best_x || (x == best_x && y > best_y) || (x == best_x && y == best_y && z > best_z) )); then best_x="$x"; best_y="$y"; best_z="$z"; fi
    fi
  done
  shopt -u nullglob
  (( best_x < 0 )) && echo "0.0.1" || echo "${best_x}.${best_y}.$((best_z + 1))"
}

build_number_for_version() { local x y z; IFS='.' read -r x y z <<< "$1"; echo $((x * 1000000 + y * 1000 + z)); }
copy_required() { [[ -f "$1" ]] || { echo "Missing build artifact: $1" >&2; exit 1; }; cp "$1" "$2"; echo "Saved: $2"; }

validate_key_properties() {
  [[ -f "$KEY_PROPERTIES" ]] || return 1
  for key in storePassword keyPassword keyAlias storeFile; do [[ -n "$(sed -n "s/^${key}=//p" "$KEY_PROPERTIES" | tail -n 1)" ]] || return 1; done
  local store_file; store_file="$(sed -n 's/^storeFile=//p' "$KEY_PROPERTIES" | tail -n 1)"
  [[ "$store_file" = /* ]] || store_file="$ANDROID_DIR/app/$store_file"
  [[ -f "$store_file" ]]
}

setup_release_signing() {
  local store_password key_password
  if validate_key_properties; then echo "Using release signing config: $KEY_PROPERTIES"; return; fi
  command -v keytool >/dev/null || { echo "keytool is required." >&2; exit 1; }
  read -r -s -p "New keystore password: " store_password; echo
  [[ -n "$store_password" ]] || { echo "Keystore password cannot be empty." >&2; exit 1; }
  read -r -s -p "New key password (blank = same): " key_password; echo
  [[ -n "$key_password" ]] || key_password="$store_password"
  keytool -genkeypair -v -keystore "$UPLOAD_KEYSTORE" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias "$UPLOAD_KEY_ALIAS" -storepass "$store_password" -keypass "$key_password" -dname "CN=Xeta Notifications Organizer, OU=Xetawallet, O=Xetawallet, L=Unknown, S=Unknown, C=IN"
  {
    echo "storePassword=$store_password"
    echo "keyPassword=$key_password"
    echo "keyAlias=$UPLOAD_KEY_ALIAS"
    echo "storeFile=../upload-keystore.jks"
  } > "$KEY_PROPERTIES"
  chmod 600 "$KEY_PROPERTIES" "$UPLOAD_KEYSTORE"
}

verify_not_debug_signed() {
  local artifact="$1" cert_output
  if [[ "$artifact" == *.apk ]]; then
    local apksigner_bin; apksigner_bin="$(find "${ANDROID_HOME:-$HOME/Android/Sdk}" -type f -name apksigner 2>/dev/null | sort -V | tail -n 1)"
    [[ -n "$apksigner_bin" ]] || { echo "apksigner is required." >&2; exit 1; }
    cert_output="$("$apksigner_bin" verify --print-certs "$artifact" 2>&1)"
  else
    command -v jarsigner >/dev/null || { echo "jarsigner is required." >&2; exit 1; }
    cert_output="$(jarsigner -verify -certs -verbose "$artifact" 2>&1 || true)"
  fi
  grep -q "CN=Android Debug" <<< "$cert_output" && { echo "Release is debug signed: $artifact" >&2; exit 1; }
  echo "Verified release signature: $artifact"
}

clean_visible_build_dir() {
  local tmp_dir; tmp_dir="$(mktemp -d)"
  cp -a "$TEST_DIR" "$tmp_dir/Test" 2>/dev/null || mkdir -p "$tmp_dir/Test"
  cp -a "$PROD_DIR" "$tmp_dir/To be Uploaded" 2>/dev/null || mkdir -p "$tmp_dir/To be Uploaded"
  cp -a "$UPLOADED_DIR" "$tmp_dir/Uploaded" 2>/dev/null || mkdir -p "$tmp_dir/Uploaded"
  rm -rf "$ROOT_DIR/build"; mkdir -p "$APK_DIR"
  cp -a "$tmp_dir/Test" "$TEST_DIR"; cp -a "$tmp_dir/To be Uploaded" "$PROD_DIR"; cp -a "$tmp_dir/Uploaded" "$UPLOADED_DIR"
  touch "$APK_DIR/.gitkeep" "$TEST_DIR/.gitkeep" "$PROD_DIR/.gitkeep" "$UPLOADED_DIR/.gitkeep"
  rm -r "$tmp_dir"
}

read -r -p "Build type [test/release]: " build_type
case "${build_type,,}" in
  test|t)
    version="$(next_test_version)"
    build_number="$(build_number_for_version "$version")"
    echo "Building test-v-${version}.apk"
    flutter build apk --debug --build-name "$version" --build-number "$build_number"
    copy_required "$ROOT_DIR/build/app/outputs/flutter-apk/app-debug.apk" "$TEST_DIR/test-v-${version}.apk"
    clean_visible_build_dir
    ;;
  release|r)
    read -r -p "Release version x.y.z: " version
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version." >&2; exit 1; }
    build_number="$(build_number_for_version "$version")"; release_dir="$PROD_DIR/$version"
    setup_release_signing
    flutter build apk --release --build-name "$version" --build-number "$build_number"
    mkdir -p "$release_dir"; copy_required "$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk" "$release_dir/release-v-${version}.apk"; verify_not_debug_signed "$release_dir/release-v-${version}.apk"
    flutter build appbundle --release --build-name "$version" --build-number "$build_number"
    copy_required "$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab" "$release_dir/release-v-${version}.aab"; verify_not_debug_signed "$release_dir/release-v-${version}.aab"
    clean_visible_build_dir
    ;;
  *) echo "Invalid build type. Use test or release." >&2; exit 1 ;;
esac
