This assumes we're using Xcode 15.x.

If packages have changed:
  - In Xcode, choose menu _File_ > _Packages_ > _Reset Package Caches_

To create a debug app distribution:
  - Make sure the correct app id, team id, and group id are specified in Config/Mac/Developer-macOS.xcconfig
  - In Xcode, choose menu _Product_ > _Archive_
  - After Xcode builds the archive, the _Archives_ window is shown, with the latest build archive selected
  - Click on _Distribute App_
  - Select _Debugging_, then click on _Distribute_
  - Click on _Export_, select a place to save the .app file

