#!/bin/bash
set -e
rm -rf "$SRCROOT/eduVPN/Resources/Assets.xcassets"
cp -R "$SRCROOT/eduVPN/Config/Assets-$APP_NAME.xcassets" "$SRCROOT/eduVPN/Resources/Assets.xcassets"

