# Play Store & App Store Submission Checklist

## ✅ Completed Optimizations

### Code Quality
- ✅ Fixed all 44 Flutter analyze issues (deprecated APIs, unused imports, print statements)
- ✅ Renamed files to follow naming conventions (snake_case)
- ✅ Removed unused code and variables
- ✅ Replaced deprecated `withOpacity` with `withValues`

### Package Configuration
- ✅ Updated Android package name: `com.example.bmsmobileapp` → `com.manah.bms`
- ✅ Updated iOS bundle identifier: `com.example.bmsmobileapp` → `com.manah.bms`
- ✅ Updated app display name: "bmsmobileapp" → "Smart BMS"
- ✅ Updated app description in pubspec.yaml

### Security
- ✅ Removed `android:usesCleartextTraffic="true"` (security improvement)
- ✅ Properly configured Bluetooth permissions for Android 12+
- ✅ Configured location permissions for Bluetooth scanning

### Build Configuration
- ✅ Configured ProGuard rules for code obfuscation
- ✅ Set up release build configuration
- ✅ Created signing configuration template
- ✅ Successfully built release APK (65.5MB)

### Firebase
- ✅ Updated Firebase configuration with new package name
- ✅ Documented Firebase setup requirements

## ⚠️ Action Required Before Store Submission

### 1. Firebase Configuration (CRITICAL)
**Follow the steps in `FIREBASE_SETUP.md`**
- Regenerate `google-services.json` from Firebase Console for `com.manah.bms`
- Regenerate `GoogleService-Info.plist` from Firebase Console for `com.manah.bms`
- Add SHA-256 fingerprint after creating release keystore

### 2. Android Release Signing (CRITICAL)
**Follow the steps in `ANDROID_SIGNING.md`**
- Generate release keystore
- Create `android/key.properties` file
- Update `android/app/build.gradle.kts` to use keystore
- Add keystore files to `.gitignore`
- Get SHA-256 fingerprint and add to Firebase Console

### 3. Code Shrinking (OPTIONAL)
- Currently disabled due to R8/ProGuard conflicts
- Can be re-enabled after refining ProGuard rules
- Not required for store submission but recommended for smaller APK size

### 4. iOS Configuration
- Bundle identifier updated to `com.manah.bms`
- Display name updated to "Smart BMS"
- Need to configure signing in Xcode before building for App Store
- Need to add Firebase `GoogleService-Info.plist`

### 5. App Store Assets
- Ensure app icons meet Apple's guidelines
- Ensure splash screens are properly configured
- Add screenshots for different device sizes
- Prepare app preview videos (optional but recommended)

### 6. Store Listing Information
- App description (drafted in pubspec.yaml, may need refinement)
- Privacy policy URL (required for both stores)
- Content rating questionnaire
- Store listing screenshots (at least 2 for Play Store, 3 for App Store)
- App icon (512x512 for Play Store, 1024x1024 for App Store)
- Feature graphic (1024x500 for Play Store)

### 7. Testing
- Test the release APK on physical devices
- Test all features: Bluetooth connection, authentication, Firebase services
- Test on different Android versions (API 21+)
- Test on different screen sizes

## 📋 Build Commands

### Android
```bash
# Build release APK (for testing)
flutter build apk --release

# Build release App Bundle (for Play Store submission)
flutter build appbundle --release

# Build with release signing (after keystore setup)
flutter build appbundle --release
```

### iOS
```bash
# Build for iOS (requires macOS and Xcode)
flutter build ios --release

# Open in Xcode for further configuration
open ios/Runner.xcworkspace
```

## 📦 Build Output Locations

### Android
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

### iOS
- IPA: `build/ios/archive/` (after archive in Xcode)

## 🔧 Configuration Files Modified

- `android/app/build.gradle.kts` - Package name, signing config
- `android/app/src/main/AndroidManifest.xml` - App label, security
- `android/app/google-services.json` - Firebase config (needs regeneration)
- `android/app/proguard-rules.pro` - Code obfuscation rules
- `ios/Runner/Info.plist` - Bundle identifier, display name
- `ios/Runner.xcodeproj/project.pbxproj` - Bundle identifier
- `pubspec.yaml` - App description

## 📝 Documentation Created

- `FIREBASE_SETUP.md` - Firebase configuration guide
- `ANDROID_SIGNING.md` - Android keystore setup guide
- `STORE_SUBMISSION_CHECKLIST.md` - This checklist

## 🚀 Next Steps

1. **Immediate**: Generate release keystore (see `ANDROID_SIGNING.md`)
2. **Immediate**: Regenerate Firebase config files (see `FIREBASE_SETUP.md`)
3. **Before submission**: Test release build thoroughly
4. **Before submission**: Prepare store assets (screenshots, icons, descriptions)
5. **Before submission**: Create privacy policy
6. **Submission**: Build App Bundle with proper signing
7. **Submission**: Submit to Google Play Console
8. **Submission**: Submit to App Store Connect (requires macOS)

## 📊 Current Status

- **Flutter Analyze**: ✅ No issues
- **Release Build**: ✅ Successful (65.5MB APK)
- **Package Name**: ✅ Updated to `com.manah.bms`
- **Security**: ✅ Cleartext traffic disabled
- **Firebase**: ⚠️ Config needs regeneration
- **Signing**: ⚠️ Keystore needs to be created
- **Store Ready**: ⚠️ Requires keystore and Firebase config updates

## 🎯 Estimated Time to Complete

- Keystore generation: 15 minutes
- Firebase config regeneration: 20 minutes
- Testing: 1-2 hours
- Store asset preparation: 2-4 hours
- Total: ~4-7 hours before ready for submission
