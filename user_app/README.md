# ZEN MINING User App — production frontend

This is the Flutter Android user app. It contains the approved ZEN MINING UI flow, production Supabase auth wiring, device registration, usage-access bridge, wallet display and withdrawal request integration.

## Build prerequisites
Flutter SDK is required. This environment does not contain Flutter, so an Android APK/AAB compile could not be executed here.

Run from `user_app/`:

`flutter create --platforms=android .`

Then keep the provided `android/app/src/main/AndroidManifest.xml` and `android/app/src/main/kotlin/com/zenmining/app/MainActivity.kt` (the generated project supplies the standard Flutter Gradle plumbing).

Then:

`flutter pub get`

`flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

Before release, test Usage Access permission, Android background restrictions, app label/icon, signing, privacy disclosures, and the exact supported Android versions.
