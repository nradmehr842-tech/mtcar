# MTcar v25.4 Build Fix

اصلاح قطعی خطای Dart مربوط به `add_device_sheet.dart`:

- `InputDecoration` دیگر `const` نیست، چون `helperText` به متغیر `enableSmsBackup` وابسته است.
- آیکن داخل آن به‌صورت `const Icon` باقی مانده است.
- اصلاح قبلی `FilledButton.icon` نیز حفظ شده است.
- هیچ تغییری در طراحی UI ایجاد نشده است.
