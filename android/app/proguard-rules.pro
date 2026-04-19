# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive
-keep class com.hivedb.** { *; }
-keep enum com.hivedb.** { *; }

# Keep your models and generated adapters
-keep class com.example.nexa_app.models.** { *; }
-keep class com.example.nexa_app.models.AnalysisResultAdapter { *; }
-keep class com.example.nexa_app.models.EleveurProfileAdapter { *; }
-keep class com.example.nexa_app.models.SavedZoneAdapter { *; }
-keep class com.example.nexa_app.models.ZoneStatusAdapter { *; }
