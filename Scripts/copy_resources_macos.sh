#!/bin/bash
set -e

# Copy Assets.xcassets for macOS

if [ -d "$SRCROOT/EduVPN/Resources/Mac/Assets-$APP_NAME.xcassets" ]; then
  rm -rf "$SRCROOT/EduVPN/Resources/Mac/Assets.xcassets"
  cp -R  "$SRCROOT/EduVPN/Resources/Mac/Assets-$APP_NAME.xcassets" "$SRCROOT/EduVPN/Resources/Mac/Assets.xcassets"
fi
