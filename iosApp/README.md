# iOS App

The iOS target is SwiftUI with bundle identifier `br.com.machadodeassis.biblioteca`.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate --spec iosApp/project.yml
xcodebuild -project MachadoBiblioteca.xcodeproj -scheme MachadoBiblioteca -sdk iphonesimulator build
```

The project targets iOS 17 and is built for App Store submissions with Xcode 26 on the `macos-26` GitHub runner. The source bundles 30 offline catalog entries, full text JSON resources, editorial visual assets, local Brazilian Portuguese speech, persisted reading state, favorites, quotes, themes, full-text search, and the Machado universe.
