# Mantener las clases de Google ML Kit Text Recognition
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Mantener clases de Firebase y Play Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Mantener el código de plugins de Flutter
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# Mantener clases usadas por reflexion
-keepattributes *Annotation*, Signature, InnerClasses
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Evitar la eliminación de recursos necesarios
-dontshrink
-dontoptimize
