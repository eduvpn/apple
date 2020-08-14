#!/bin/bash
set -e

if [ -d "$SRCROOT/EduVPN-macOS/Config/Assets-$APP_NAME.xcassets" ]; then
  rm -rf "$SRCROOT/EduVPN-macOS/Resources/Assets.xcassets"
  cp -R "$SRCROOT/EduVPN-macOS/Config/Assets-$APP_NAME.xcassets" "$SRCROOT/EduVPN-macOS/Resources/Assets.xcassets"
fi

if [ -d "$SRCROOT/EduVPN-redesign/Resources/Mac/Assets-$APP_NAME.xcassets" ]; then
  rm -rf "$SRCROOT/EduVPN-redesign/Resources/Mac/Assets.xcassets"
  cp -R  "$SRCROOT/EduVPN-redesign/Resources/Mac/Assets-$APP_NAME.xcassets" "$SRCROOT/EduVPN-redesign/Resources/Mac/Assets.xcassets"
fi
