# ── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Firebase (Auth / Firestore) ───────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn okhttp3.**
-dontwarn okio.**

# ── ML Kit ────────────────────────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
# We only bundle the Latin text recognizer; the plugin references optional
# language recognizers (Chinese/Devanagari/Japanese/Korean) we don't include.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ── Play Core (deferred components / split install) ────────────────────────────
# Flutter's embedding references Play Core for deferred components, which this
# app does not use. Ignore the missing classes so R8 doesn't fail.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Biometric ─────────────────────────────────────────────────────────────────
-keep class androidx.biometric.** { *; }

# ── Remove logging in release ─────────────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# ── General optimizations ─────────────────────────────────────────────────────
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
