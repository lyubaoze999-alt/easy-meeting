#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
app_path="${1:-$project_root/build/macos/Build/Products/Release/会议纪要.app}"
output_path="${2:-$project_root/build/releases/meeting-notes.dmg}"

if [[ ! -d "$app_path" ]]; then
  app_path="$project_root/build/macos/Build/Products/Release/easy_meeting.app"
fi
if [[ ! -d "$app_path" ]]; then
  echo "macOS release app not found" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_path")"
if [[ -n "${EASY_MEETING_MACOS_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp \
    --sign "$EASY_MEETING_MACOS_SIGN_IDENTITY" "$app_path"
fi
hdiutil create -volname "会议纪要" -srcfolder "$app_path" \
  -ov -format UDZO "$output_path"

