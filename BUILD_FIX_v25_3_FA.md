# MTcar v25.3 Build Fix

این نسخه بر اساس گزارش Diagnostics v25.2 اصلاح شد.

خطاهای واقعی رفع‌شده:

1. `account_membership_page.dart:52`
   - حذف `const` از `FilledButton.icon` چون سازنده const نیست.

2. `add_device_sheet.dart:281-286`
   - حذف `const` از `InputDecoration` چون `helperText` به مقدار runtime یعنی `enableSmsBackup` وابسته است.

Workflow نیز با نام v25.3 و Artifact جدید به‌روزرسانی شده است.

هشدارها و infoهای deprecated فعلاً Build را متوقف نمی‌کنند و تغییر ظاهری در UI ایجاد نشده است.
