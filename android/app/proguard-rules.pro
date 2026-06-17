# ✅ Keep Flutter Default Rules
-keep class io.flutter.** { *; }

# ✅ Keep Your App Package
-keep class com.agni.agni_car_rental.** { *; }

# ✅ Preserve Google Play Core API (Fixes R8 Issues)
-keep class com.google.android.play.** { *; }
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }

# ✅ Keep AndroidX Core Libraries
-keep class androidx.appcompat.** { *; }

# ✅ General Android Components (Prevents Crashes)
-keep class * extends android.app.Application { *; }
-keep class * extends android.app.Service { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.content.ContentProvider { *; }

# ✅ Prevent Removing @JavascriptInterface Methods (WebView Fix)
-keepclassmembers class * { 
    @android.webkit.JavascriptInterface <methods>;
}

# ✅ Retain Serialized Data
-keepclassmembers class * implements java.io.Serializable { *; }

# Keep Flutter Play Store Split Application classes
-keep class io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager { *; }


# Prevent Removing Annotations
-keepattributes *Annotation*

# Flutter Default ProGuard Rules
-keep class com.example.** { *; }


# Prevent Stripping Parcelable Data
-keep class * implements android.os.Parcelable { *; }

# Keep Retrofit / JSON Parsing Models
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }

# Keep AndroidX Core & Reflection
-keep class androidx.core.** { *; }
-keep class androidx.lifecycle.** { *; }

# Retain Serialized Data
-keep class * implements java.io.Serializable { *; }














