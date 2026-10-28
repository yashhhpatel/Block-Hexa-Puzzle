# Release-build shrinking (R8) rules.

# Google Mobile Ads pulls in WorkManager, which uses Room. R8 strips Room's
# generated database classes (e.g. androidx.work.impl.WorkDatabase_Impl),
# because they are only created by reflection, and the app then crashes on
# launch with "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
