#!/bin/bash
set -e
rm -rf $SRCROOT/EduVPN/Resources/Assets.xcassets
cp -R $SRCROOT/EduVPN/Config/Assets-$APP_NAME.xcassets $SRCROOT/EduVPN/Resources/Assets.xcassets

