# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep WorkManager classes
-keep class androidx.work.** { *; }

# Keep notification classes
-keep class com.dexterous.** { *; }

# Keep home_widget classes
-keep class es.antonborri.home_widget.** { *; }

# Keep Adapty classes
-keep class com.adapty.** { *; }
-keepattributes *Annotation*

# Play Core (needed by Flutter deferred components)
-dontwarn com.google.android.play.core.**
