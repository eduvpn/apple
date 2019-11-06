#!/bin/bash
set -e
rm -rf $SRCROOT/EduVPN-macOS/Resources/Assets.xcassets
cp -R "$SRCROOT/EduVPN-macOS/Config/Assets-$APP_NAME.xcassets" $SRCROOT/EduVPN-macOS/Resources/Assets.xcassets

