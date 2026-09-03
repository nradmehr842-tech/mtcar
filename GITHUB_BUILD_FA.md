# MTcar — GitHub Actions APK Build

این نسخه برای ساخت خودکار APK روی GitHub Actions آماده شده است.

## روش سریع

1. در GitHub یک Repository جدید بساز.
2. تمام محتویات این ZIP را داخل Repository آپلود کن.
3. اگر GitHub فایل‌ها را داخل یک پوشه اضافه کرد، مطمئن شو `.github` و `mobile` و `scripts` مستقیماً در ریشه Repository باشند.
4. Commit را انجام بده.
5. وارد تب `Actions` شو.
6. Workflow با نام `Build MTcar Android APK` را باز کن.
7. `Run workflow` را بزن.
8. بعد از پایان Build، پایین صفحه قسمت `Artifacts` ظاهر می‌شود.
9. `MTcar-Android-APK` را دانلود کن.
10. داخل فایل دانلودشده، `MTcar-debug.apk` قرار دارد.

## خروجی

`MTcar-debug.apk`

این نسخه Debug و برای نصب و تست مستقیم روی Android است.

## نکته

اتصال واقعی VPS، SMS Provider، Payment Provider، SIM Top-up Provider و ردیاب واقعی در مرحله Deployment تنظیم می‌شوند.
