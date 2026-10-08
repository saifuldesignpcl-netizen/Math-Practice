# Math Practice - Flutter (Android)

PySide6 desktop app-er Flutter/Android version.

## Build korar niyom

1. Flutter SDK + Android Studio (Android SDK) install korun, tarpor `flutter doctor` chalan.
2. Notun project baniye nin (Android-er jonno):

       flutter create --platforms=android --project-name math_practice math_practice
       cd math_practice

3. `lib/main.dart` ke ei zip-er `lib/main.dart` diye replace korun.
   `pubspec.yaml` o replace korte paren (kono extra package lage na).
4. Default test file muche din (oita counter app-er jonno, ar na muchle `flutter analyze` error dey):

       rm test/widget_test.dart

5. Phone/emulator-e chalan:

       flutter run

6. APK banan:

       flutter build apk --release

   Ready APK: `build/app/outputs/flutter-apk/app-release.apk`
   (Play Store-er jonno `flutter build appbundle`)

## App-er naam
`android/app/src/main/AndroidManifest.xml`-e `android:label="Math Practice"` kore din.
