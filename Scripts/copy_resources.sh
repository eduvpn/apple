#!/bin/bash
set -e

# Copy Assets.xcassets for iOS

if [ -d "$SRCROOT/EduVPN/Resources/iOS/Assets-$APP_NAME.xcassets" ]; then
  rm -rf "$SRCROOT/EduVPN/Resources/iOS/Assets.xcassets"
  cp -R "$SRCROOT/EduVPN/Resources/iOS/Assets-$APP_NAME.xcassets" "$SRCROOT/EduVPN/Resources/iOS/Assets.xcassets"
fi
