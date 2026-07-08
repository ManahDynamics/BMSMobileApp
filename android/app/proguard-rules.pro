# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Bluetooth
-keep class com.lib.flutter_blue_plus.** { *; }
-keepattributes InnerClasses
-keep class * { *; }

# SQLite
-keep class * implements android.database.sqlite.SQLiteDatabase { *; }

# Keep model classes
-keep class com.manah.bms.** { *; }
-keep class com.manah.bms.models.** { *; }

# Keep serialization classes
-keepattributes *Annotation*
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
