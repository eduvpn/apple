#!/bin/bash
set -e

# Copy Assets.xcassets for iOS

if [ -d "$SRCROOT/eduVPN/Config/Assets-$APP_NAME.xcassets" ]; then
  rm -rf "$SRCROOT/eduVPN/Resources/Assets.xcassets"
  cp -R "$SRCROOT/eduVPN/Config/Assets-$APP_NAME.xcassets" "$SRCROOT/eduVPN/Resources/Assets.xcassets"
fi

if [ -d "$SRCROOT/EduVPN-redesign/Resources/iOS/Assets-eduVPN.xcassets" ]; then
  rm -rf "$SRCROOT/EduVPN-redesign/Resources/iOS/Assets.xcassets"
  cp -R "$SRCROOT/EduVPN-redesign/Resources/iOS/Assets-eduVPN.xcassets" "$SRCROOT/EduVPN-redesign/Resources/iOS/Assets.xcassets"
fi
