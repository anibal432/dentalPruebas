# Prevent proguard from stripping interface information from TypeAdapter, TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances (so they can be used in @JsonAdapter)
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Retain generic signatures of TypeToken and its subclasses with R8 version 3.0 and higher.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

-keepattributes Signature
-keepattributes *Annotation*

# --- Fix: R8 missing class error con ML Kit + Firebase (FirebaseInstanceId ya no existe) ---
-dontwarn com.google.firebase.iid.FirebaseInstanceId
-dontwarn com.google.mlkit.linkfirebase.**
-dontwarn com.google.android.gms.internal.mlkit_linkfirebase.**

# --- Fix: Google Sign-In / Firebase Auth se rompe en release con minify activado ---
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.signin.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class androidx.credentials.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }