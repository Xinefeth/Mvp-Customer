# =============================
# PROGUARD RULES FOR FLUTTER + MLKIT OCR
# =============================

# Mantener todas las clases de Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Mantener todas las clases de Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.android.gms.internal.**

# 🔹 Solución directa al error “Missing class com.google.mlkit.vision.text.*”
-keep class com.google.mlkit.vision.text.TextRecognizer { *; }
-keep class com.google.mlkit.vision.text.TextRecognizerOptionsInterface { *; }
-keep class com.google.mlkit.vision.text.Text { *; }
-keep class com.google.mlkit.vision.text.Text$** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Evitar advertencias por anotaciones o librerías internas
-dontwarn javax.annotation.**
-keepattributes *Annotation*

# Opcional: mantener logs y nombres (solo si depuras)
-keepattributes SourceFile,LineNumberTable
