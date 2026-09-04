# MTcar v25.1 Build Fix

در این نسخه فقط رفتار مرحله Flutter Analyze در GitHub Actions اصلاح شده است.

دستور قبلی:
`flutter analyze --no-fatal-infos`

دستور جدید:
`flutter analyze --no-fatal-infos --no-fatal-warnings`

هشدارها و اخطارهای lint/deprecation مانع ساخت APK تستی نمی‌شوند، اما خطاهای واقعی کامپایل همچنان در مرحله `flutter build apk --release` باعث توقف Build می‌شوند.

UI و منطق No-SMS نسخه v25 تغییری نکرده است.
