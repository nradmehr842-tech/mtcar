# ساخت APK اصلی MTcar v25

این بسته نسخه اصلی فعلی MTcar است. UI از تصاویر قفل‌شده در `ui_reference_locked/` گرفته شده و منطق فنی آخرین نسخه حفظ شده است.

## ساخت APK در GitHub

1. محتوای ZIP را در ریشه Repository قرار بده.
2. در GitHub وارد `Actions` شو.
3. Workflow با نام `Build MTcar v25 Main APK` را باز کن.
4. `Run workflow` را بزن.
5. پس از موفقیت Build، Artifact زیر را دانلود کن:

`MTcar-v25-No-SMS-APK`

فایل APK داخل Artifact:

`MTcar-v25-release.apk`

## Backend تولید

APK با این آدرس Build می‌شود:

`https://api.mediatelecom.ir`

تا زمانی که Backend و DNS/SSL روی این دامنه Deploy نشده باشند، Login و سرویس‌های آنلاین واقعی کار نخواهند کرد. اپ مقدار ساختگی برای داده‌های سرور، SIM، سوخت، RPM یا دما نمایش نمی‌دهد.

## ردیاب فعلی

- Brand: MTcar
- Model: MT120
- Protocol: gps103
- Port: TCP 5001

فعلاً انتخاب مدل از Login/Register حذف شده است. مدل‌های بعدی از پنل مدیریت سرور اضافه می‌شوند و در فرایند افزودن دستگاه داخل اپ نمایش داده می‌شوند؛ در حالت عادی نیازی به APK جدید نیست.

## Signing

Workflow فعلی یک Release APK قابل نصب برای تست/استقرار مستقیم می‌سازد. برای انتشار رسمی Store باید Keystore دائمی MTcar ساخته شود و در GitHub Secrets نگهداری شود.


## احراز هویت v25

- ثبت‌نام: نام کاربری + رمز عبور + تکرار رمز عبور
- ورود: نام کاربری + رمز عبور
- پیامک/OTP برای حساب کاربری لازم نیست.
- SMS Backup ردیاب اختیاری و مستقل است.
