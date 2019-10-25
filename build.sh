#!/bin/bash
echo "Build Script for EduVPN iOS"

echo ""
echo "Which signing identity do you want to use?"
echo "1. SURFnet B.V. (ZYJ4TZX4UU)"
echo "2. Jeroen Leenarts (T4CMEHXPLL)"
echo "3. Commons Caretakers (D9T87NF4Q7)"
echo "4. Other"
read -p "0-9?" choice
case "$choice" in
  1 ) TEAMID="ZYJ4TZX4UU"; SIGNINGIDENTITY="Developer ID Application: SURFnet B.V. ($TEAMID)"; PROFILETYPE="app-store"; PRODUCT="EduVPN";;
  2 ) TEAMID="T4CMEHXPLL"; SIGNINGIDENTITY="iPhone Distribution"; PROFILETYPE="ad-hoc"; PRODUCT="EduVPN-test";;
  3 ) TEAMID="D9T87NF4Q7"; SIGNINGIDENTITY="iPhone Distribution"; PROFILETYPE="app-store"; PRODUCT="LetsConnect";;
  4 ) echo "Please adjust the build script to add your signing identity."; exit 0;;
  * ) echo "Invalid response."; exit 0;;
esac

BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo ""
echo "You are currently on branch $BRANCH."

if [[ $BRANCH != "master" ]]
then
    echo ""
    echo "You must always build from master branch. Switch to the correct branch."
    exit
fi

git=$(sh /etc/profile; which git)
git_release_version=$("$git" describe --tags --always --abbrev=0)
number_of_commits=$("$git" rev-list HEAD --count)
git_release_version=${git_release_version//[v]/}

VERSION="$git_release_version-$number_of_commits"

echo ""
read -p "Continue building $PRODUCT version $VERSION (using $SIGNINGIDENTITY) (y/n)?" choice
case "$choice" in
  y|Y ) ;;
  n|N ) exit 0;;
  * ) echo "Invalid response."; exit 0;;
esac

TARGET="EduVPN"
FILENAME="$PRODUCT-$VERSION"

echo ""
echo "Building and archiving"
xcodebuild archive -workspace EduVPN.xcworkspace -scheme $TARGET -archivePath $FILENAME.xcarchive DEVELOPMENT_TEAM=$TEAMID

echo "Exporting not yet supported"
exit 0

echo ""
echo "Exporting"
/usr/libexec/PlistBuddy -c "Set :teamID \"$TEAMID\"" ExportOptions.plist
/usr/libexec/PlistBuddy -c "Set :method \"$PROFILETYPE\"" ExportOptions.plist
/usr/libexec/PlistBuddy -c "Set :signingCertificate \"$SIGNINGIDENTITY\"" ExportOptions.plist
xcodebuild -exportArchive -archivePath $FILENAME.xcarchive -exportPath $FILENAME -exportOptionsPlist ExportOptions.plist

echo ""
echo "Done! You can now upload the archive to the AppStore. Also remember to set a new version tag on the next commit on master."
