# MTcar — Main Source v24 Exact UI

نسخه بازنویسی‌شده برای Coban ردیاب خودرو / GPS303F با معماری یکپارچه.

## معماری

```text
ردیاب خودرو
 ├─ GPRS / GPS103 → VPS Iran (Public Static IPv4:5001) → Traccar → Backend API → App
 └─ SMS Backup → Android Phone → Native SMS Receiver → Critical Alarm → App Event Log
```

## هویت دستگاه

- شناسه اصلی دستگاه در سرور: IMEI / Unique ID
- شماره سیم‌کارت ردیاب: برای SMS Backup، فرمان‌های SMS و استعلام مانده شارژ
- رمز پیش‌فرض رایج دستگاه: 123456 (در نصب واقعی حتماً تغییر داده شود)

## امکانات

### رهگیری
- Live position
- Speed / Course
- Online / Offline
- ACC / Ignition
- Door status
- GPS/GPRS/GSM status
- Route history
- Geofence
- Last known location when offline

### امنیت
- Door Alarm
- ACC / Ignition Alarm
- Movement Alarm
- Shock / Vibration Alarm
- External Power Cut
- Vehicle battery disconnect / tracker power unplug
- Low Battery
- SOS
- GPS blind spot
- Possible Tracker Tamper:
  - Power Cut + Shock/Movement within 120 seconds
- Critical Android alarm:
  - High Priority Notification
  - Alarm sound
  - Vibration
  - Full-screen lock-screen alarm when allowed
  - Saved event history

### کنترل خودرو
- Engine Stop
- Engine Resume
- Server-side speed safety gate
- Default: engine stop is blocked above configured safe speed

### باتری دستگاه
دکمه Device Check فرمان وضعیت دستگاه را ارسال می‌کند و پاسخ SMS می‌تواند شامل:
- Battery
- Power
- GPS
- ACC
- Door
- GSM Signal
- GPRS

### سیم‌کارت
- نمایش شماره سیم‌کارت
- SIM Balance Inquiry
- ثبت پاسخ موجودی در اپ
- Top-up UI
- Backend Top-up Provider interface
- خرید واقعی شارژ فقط بعد از اتصال API یک سرویس پرداخت/شارژ مجاز انجام می‌شود.

## نقشه

کل اپ به یک Provider خاص قفل نشده است:

```text
MapProvider
 ├─ BaladAdapter     (preferred when official SDK/API credentials are available)
 ├─ NeshanAdapter    (Iranian provider option)
 └─ OSMAdapter       (fallback)
```

در نسخه فعلی، Provider واقعی باید با API Key/SDK معتبر همان سرویس فعال شود.
هیچ URL یا Tile Endpoint حدسی برای بلد داخل پروژه hard-code نشده است.

## سرور پیشنهادی

- Iran VPS
- Ubuntu 24.04
- Public Static IPv4
- 2 GB RAM recommended
- Ports:
  - 5001/TCP: ردیاب خودرو / GPS103 → Traccar
  - 443/TCP: App API
  - 80/TCP: certificate/redirect if needed

## تنظیم اولیه ردیاب خودرو

یک‌بار روی دستگاه:
- APN اپراتور
- Server IP/Domain
- Port 5001
- GPRS mode

بعد از آن دستگاه با IMEI روی Traccar شناخته می‌شود.

## پوشه‌ها

- `server/` : Backend Node.js
- `mobile/` : Flutter application skeleton
- `mobile/android_native_overlay/` : Android SMS + Critical Alarm native layer
- `preview/` : Browser preview


## حساب کاربری و اشتراک — v6

### ورود و رمز برنامه
رمز حساب برنامه از رمز ردیاب خودرو جدا است:

- شماره موبایل: شناسه ورود کاربر
- رمز ورود برنامه: برای حساب MTcar
- رمز ردیاب خودرو: فقط برای فرمان‌های SMS خود ردیاب

رمز ورود برنامه با bcrypt روی سرور Hash می‌شود و متن خام ذخیره نمی‌شود.

### تغییر شماره موبایل
مسیر امن:

1. کاربر باید وارد حساب باشد.
2. رمز فعلی حساب را وارد کند.
3. شماره موبایل جدید ثبت شود.
4. OTP شش‌رقمی به شماره جدید ارسال شود.
5. بعد از تأیید OTP، شماره Login عوض و JWT جدید صادر شود.

### تغییر رمز
- رمز فعلی بررسی می‌شود.
- رمز جدید حداقل ۸ کاراکتر است.
- Hash جدید در PostgreSQL ذخیره می‌شود.

### اشتراک سالانه
- مبلغ از `SUBSCRIPTION_ANNUAL_PRICE_TOMAN` روی VPS خوانده می‌شود.
- مبلغ داخل APK Hard-code نمی‌شود.
- Checkout فقط از Backend ساخته می‌شود.
- Verify پرداخت فقط Server-side است.
- پس از Verify موفق، اشتراک دقیقاً ۱۲ ماه تمدید می‌شود.
- اگر قبل از پایان اعتبار تمدید شود، ۱۲ ماه به انتهای اشتراک فعلی اضافه می‌شود.
- رسید و تاریخچه پرداخت در Database ذخیره می‌شود.

### دسترسی پس از پایان اشتراک
Cloud features مثل رهگیری سروری، History و فرمان‌های سرور با Middleware اشتراک محافظت شده‌اند.
مسیرهای حساب، پرداخت و قابلیت‌های محلی Android/SMS Backup از این Gate جدا هستند تا کاربر بتواند وارد حساب شود و اشتراک را تمدید کند.

### Database
PostgreSQL اضافه شده و شامل:
- users
- otp_challenges
- subscriptions
- membership_payments

### درگاه پرداخت
`membership-payment.js` یک Adapter عمومی دارد. پرداخت واقعی تا وقتی API رسمی یک درگاه و API Key آن تنظیم نشود غیرفعال است.


## Voice Monitor — v7

- دکمه «شنیدن صدای داخل خودرو»
- ارسال `monitor+password`
- باز کردن Dialer روی شماره سیم‌کارت ردیاب خودرو
- دکمه «پایان شنیدن صدا و بازگشت به رهگیری»
- ارسال `tracker+password`
- تشخیص پاسخ‌های `monitor ok` و `tracker ok`
- بدون ضبط صدا
- با Confirmation حریم خصوصی قبل از فعال‌سازی

نکته مهم: در Monitor Mode، GPS303 رهگیری GPS را متوقف می‌کند؛ پس بعد از پایان تماس باید Tracker Mode دوباره فعال شود.


## Server-Driven Admin Panel — v8

نسخه v8 نرم‌افزار را به یک پنل مدیریت مرکزی متصل می‌کند.

### اپ کاربر چه چیزهایی را از سرور می‌خواند؟

endpoint:
`GET /api/app/bootstrap`

در هر ورود/بازگشت به برنامه، اپ می‌تواند این اطلاعات را Refresh کند:

- قیمت اشتراک سالانه
- وضعیت اشتراک
- تاریخ پایان اشتراک
- تعداد روزهای باقی‌مانده
- اطلاعیه مدیر
- حداقل نسخه نرم‌افزار
- Force Update
- Feature Flags
- Provider نقشه
- اطلاعات دستگاه‌های کاربر
- IMEI
- شماره سیم‌کارت داخل ردیاب
- نوع/آیکن وسیله

مقادیر داخل APK ثابت نیستند و `Cache-Control: no-store` برای Bootstrap در نظر گرفته شده است.

### Remote Config

جدول:
`remote_config`

نمونه کلیدها:
- `subscription.annual_price_toman`
- `subscription.grace_days`
- `app.support_phone`
- `app.announcement`
- `app.minimum_version`
- `app.force_update`
- `features.sms_backup`
- `features.voice_monitor`
- `features.engine_control`
- `map.preferred_provider`

مدیر می‌تواند این مقادیر را بدون انتشار APK جدید تغییر دهد.

### پنل مدیریت

Admin می‌تواند ببیند:

- شماره موبایل ثبت‌نام کاربر
- وضعیت حساب
- تاریخ ثبت‌نام
- روزهای باقی‌مانده اشتراک
- تاریخ پایان عضویت
- مبلغ آخرین پرداخت
- تاریخ آخرین پرداخت
- IMEI هر دستگاه
- شماره سیم‌کارت داخل ردیاب خودرو
- نام وسیله
- نوع وسیله
- آیکن وسیله
- تاریخچه اشتراک
- تاریخچه پرداخت‌ها

Admin می‌تواند:

- کاربر را Active / Suspended کند
- روز اشتراک اضافه/کم کند
- قیمت اشتراک سالانه را تغییر دهد
- Remote Config را تغییر دهد
- اطلاعیه عمومی منتشر کند
- Feature Flagها را روشن/خاموش کند

### Audit Log

تمام عملیات مدیریتی مهم در:
`admin_audit_log`
ثبت می‌شوند، از جمله:
- تغییر وضعیت کاربر
- تغییر روزهای اشتراک
- تغییر Remote Config

### امنیت Admin

- Role در JWT ثبت می‌شود.
- endpointهای `/api/admin/*` فقط برای `role=admin` هستند.
- کاربران عادی به Admin API دسترسی ندارند.
- Password hash شده باقی می‌ماند.
- اطلاعات حساس ردیاب فقط در Admin Authenticated endpoints نمایش داده می‌شود.

### User-Device relation

جدول جدید:
`user_devices`

فیلدهای کلیدی:
- user_id
- traccar_device_id
- imei
- tracker_sim_phone
- vehicle_name
- vehicle_type
- vehicle_icon
- is_active


## Organization Web Portal + Support Center — v9

### نسخه تحت وب سازمانی

برای سازمان‌ها و شرکت‌های دارای چند خودرو، یک Portal جدا در نظر گرفته شده است.

پیشنهاد آدرس:

- `app.mediatelecom.ir` → اپ/پنل وب کاربران و سازمان‌ها
- `admin.mediatelecom.ir` → پنل مدیریت مرکزی
- `api.mediatelecom.ir` → Backend API
- ردیاب خودرو → Public Static IP روی TCP 5001

### ساختار سازمان

جداول:
- `organizations`
- `organization_members`

Roleهای سازمانی:
- `owner`
- `manager`
- `dispatcher`
- `viewer`

هر سازمان می‌تواند:
- چند خودرو داشته باشد
- چند کاربر داشته باشد
- برای کاربران نقش متفاوت تعریف کند
- همه خودروها را روی یک نقشه ببیند
- وضعیت Online/Offline را ببیند
- IMEI و سیم‌کارت ردیاب هر خودرو را مدیریت کند
- تاریخچه مسیر و Eventها را ببیند
- اشتراک سازمانی داشته باشد
- Ticket پشتیبانی سازمانی ثبت کند

### پشتیبانی / تماس

جداول:
- `support_tickets`
- `support_messages`

کاربر از داخل اپ یا نسخه وب می‌تواند:
- موضوع پیام را انتخاب کند
- متن پیام بفرستد
- Priority تعیین کند
- پیام را به حساب شخصی یا سازمان مرتبط کند
- پاسخ مدیر را داخل همان نرم‌افزار ببیند
- ادامه مکالمه را در همان Ticket انجام دهد

مدیر در پنل می‌تواند:
- همه Ticketها را ببیند
- براساس وضعیت و Priority فیلتر کند
- پیام کاربر را باز کند
- مستقیم پاسخ بدهد
- Note داخلی بنویسد
- Ticket را Open / Pending / Answered / Closed کند
- Ticket را به Admin خاص Assign کند

### درباره ما / تماس

این موارد نیز Remote Config هستند و از سرور می‌آیند:
- `app.about_title`
- `app.about_text`
- `app.support_phone`
- `app.support_email`

بنابراین متن «درباره ما» و اطلاعات تماس بدون انتشار APK جدید قابل تغییر است.

### Admin visibility

مدیر علاوه بر کاربران شخصی، سازمان‌ها را هم می‌بیند:
- نام سازمان
- تعداد خودروها
- تعداد اعضا
- وضعیت اشتراک
- روزهای باقی‌مانده
- Ticketهای پشتیبانی


## برند نهایی — v10

نام محصول و سامانه از این نسخه:

# MTcar
English brand: `MTcar`

برند قبلی و نام مدل سخت‌افزاری از رابط کاربری، پنل‌ها و سایت حذف شده است.
معماری عمداً Device-Agnostic نگه داشته شده تا بعداً مدل‌های ردیاب سازگار دیگری نیز بتوانند به سامانه اضافه شوند.

دامنه‌ها:
- `mediatelecom.ir` → سایت معرفی محصول
- `app.mediatelecom.ir` → سامانه کاربران و سازمان‌ها
- `admin.mediatelecom.ir` → مدیریت مرکزی
- `api.mediatelecom.ir` → API


## تاریخچه v22 (منسوخ) — UI قبلی

هویت رسمی محصول:
- نام: `MTcar`
- رنگ اصلی: قرمز `#E10600`
- سفید: `#FFFFFF`
- طوسی روشن: `#F3F4F6`
- گرافیت: `#2B2F36`

### شنود آنلاین
دکمه «شنود آنلاین» علاوه بر تب امنیت، به صفحه اصلی و بخش «دسترسی سریع» منتقل شد.

Flow:
1. کاربر «شنود آنلاین» را می‌زند.
2. هشدار حریم خصوصی و توقف موقت GPS نشان داده می‌شود.
3. `monitor+password` برای دستگاه ارسال می‌شود.
4. Dialer شماره سیم‌کارت ردیاب باز می‌شود.
5. پس از پایان، «پایان شنود» فرمان `tracker+password` را ارسال می‌کند.
6. رهگیری GPS دوباره فعال می‌شود.

ضبط صدا داخل MTcar پیاده‌سازی نشده است.


## SIM Balance & Internet Management — v12

MTcar از این نسخه اطلاعات سیم‌کارت ردیاب را به‌صورت Server-driven مدیریت می‌کند.

### رفتار واقعی UI
- اگر موجودی شارژ واقعی دریافت شود → مبلغ نمایش داده می‌شود.
- اگر حجم اینترنت واقعی دریافت شود → حجم/بسته/انقضا نمایش داده می‌شود.
- اگر منبع معتبر پاسخ ندهد → `در دسترس نیست`.
- زمان آخرین استعلام همیشه ذخیره می‌شود.
- هیچ عدد Demo به‌عنوان موجودی واقعی نشان داده نمی‌شود.

### کدهای اپراتور در پروژه
همراه اول:
- موجودی شارژ: `*10*121#`
- وضعیت اینترنت: `*100*1#`
- منوی خرید بسته اینترنت: `*100#`

ایرانسل:
- موجودی شارژ: `*555*1*2#`
- وضعیت اینترنت: `*555*1*4#`
- خرید بسته اینترنت: `*555*5#`

این کدها در `carrier-codes.js` نگهداری شده‌اند.

### نکته مهم درباره USSD
USSD روی سیم‌کارتی اجرا می‌شود که جلسه USSD را اجرا کند.
چون SIM هدف داخل ردیاب است، اجرای USSD روی گوشی کاربر به SIM ردیاب اعمال نمی‌شود.

به همین دلیل:
- دکمه «شارژ اصلی» → Backend API → شماره SIM ردیاب
- دکمه «خرید بسته اینترنت» → Backend API → شماره SIM ردیاب
- دکمه «استعلام» → Operator/M2M API یا منبع معتبر
- کد USSD → فقط Fallback/reference

### API endpoints
- `GET /api/devices/:id/sim/status`
- `POST /api/devices/:id/sim/refresh`
- `GET /api/devices/:id/sim/internet-packages`
- `POST /api/devices/:id/sim/topup`
- `POST /api/devices/:id/sim/buy-package`
- `GET /api/devices/:id/sim/purchases`

### Production requirement
برای خرید واقعی شارژ و بسته باید Provider/API واقعی فروش شارژ و بسته در:
- `SIM_TOPUP_API_URL`
- `SIM_TOPUP_API_KEY`
- `SIM_PACKAGES_API_URL`

تنظیم شود.


## Multi-Tracker Device Profiles — v13
- انتخاب مدل ردیاب توسط کاربر
- کاتالوگ مدل‌ها روی سرور
- Protocol / Port / Command profile per model
- Capability Matrix برای نمایش/مخفی‌کردن امکانات
- افزودن مدل جدید بدون انتشار APK جدید
- پروفایل Generic برای AIKA تا زمان تایید مدل دقیق


## Map & Navigation Provider Selection — v14

کاربر می‌تواند از داخل MTcar Provider نقشه و مسیریاب را انتخاب کند.

### نقشه داخل برنامه
- Auto
- Google Maps
- نشان
- بلد
- OSM fallback

### مسیریابی
- Waze
- Google Maps
- نشان
- بلد

Waze به‌عنوان اپ مسیریابی خارجی/Deep Link استفاده می‌شود، نه لایه Base Map داخلی.

### تنظیمات ذخیره‌شونده برای هر کاربر
جدول:
`user_preferences`

فیلدها:
- map_provider
- navigation_provider
- map_style

### API
- `GET /api/preferences/maps`
- `PUT /api/preferences/maps`

### Credentials
Google:
`GOOGLE_MAPS_API_KEY`

Neshan:
`NESHAN_API_KEY`

Balad:
`BALAD_API_KEY`

Providerهایی که Credential معتبر ندارند در نسخه Production باید Disabled/Unavailable نمایش داده شوند.


## Subscription Expiry UX — v15

وقتی اعتبار حساب تمام شود:

1. کاربر همچنان می‌تواند Login کند.
2. `GET /api/app/bootstrap` وضعیت زیر را برمی‌گرداند:
   - `active=false`
   - `expired=true`
   - `renewalRequired=true`
   - `renewalMessage`
3. صفحه اصلی یک هشدار واضح نمایش می‌دهد:

`دوره اعتبار حساب شما به پایان رسیده است. برای شارژ به پنل حساب کاربری خود مراجعه کنید.`

4. دکمه `رفتن به حساب کاربری / تمدید` مستقیماً پنل اشتراک را باز می‌کند.
5. APIهای اشتراکی همچنان با Subscription Gate محافظت می‌شوند.
6. Account / Subscription / Payment endpoints باز می‌مانند تا کاربر بتواند تمدید کند.
7. بعد از Verify پرداخت، Bootstrap بعدی وضعیت Active را برمی‌گرداند و هشدار حذف می‌شود.

این رفتار هم برای اپ موبایل و هم نسخه وب کاربر در نظر گرفته شده است.


## One-Month Free Trial — v16

هر حساب کاربری یک بار می‌تواند یک ماه اشتراک رایگان دریافت کند.

### زمان شروع
Trial هنگام Registration شروع نمی‌شود.

فقط وقتی اولین ردیاب آن حساب برای اولین بار واقعاً Online شود:
`Tracker -> Traccar -> MTcar internal device-online event`

### مدت
یک ماه تقویمی:
`NOW() + INTERVAL '1 month'`

### ضد سوءاستفاده
Trial به حساب کاربری متصل است، نه به Device.

بنابراین:
- حذف Device
- افزودن Device جدید
- تغییر IMEI

باعث دریافت Trial جدید نمی‌شود.

فیلدهای User:
- `free_trial_started_at`
- `free_trial_ends_at`
- `free_trial_used`

فیلدهای Device:
- `first_online_at`
- `last_online_at`

### اشتراک موجود
Trial هیچ‌وقت تاریخ اشتراک پولی طولانی‌تر را کوتاه نمی‌کند.
اگر کاربر از قبل اشتراک معتبر داشته باشد، پایان اعتبار بزرگ‌تر حفظ می‌شود.

### Internal Hook
`POST /internal/device-online`

Header:
`x-mtcar-internal-token`

Environment:
`INTERNAL_EVENT_TOKEN`

این endpoint باید فقط توسط Backend/Traccar integration صدا زده شود، نه مستقیماً توسط APK.

### Bootstrap
وضعیت Trial در Bootstrap برمی‌گردد:
- `used`
- `startedAt`
- `endsAt`
- `eligible`


## Pre-Login Device Introduction — v17

کاربر از همان صفحه ورود/ثبت‌نام می‌تواند **قبل از احراز هویت** برند و مدل ردیاب خود را انتخاب کند.

### UX
- صفحه اول برنامه:
  - انتخاب برند
  - انتخاب مدل
  - نمایش Thumbnail کوچک از دستگاه
  - دکمه «ادامه و ورود / ثبت‌نام»

### رفتار
1. کاربر مدل ردیاب را قبل از Login/Register انتخاب می‌کند.
2. انتخاب او در جریان احراز هویت حفظ می‌شود.
3. پس از ورود یا ثبت‌نام، کاربر مستقیماً با همان Device Profile ادامه می‌دهد.
4. فرم افزودن دستگاه، پروتکل، پورت و امکانات سازگار را براساس همان مدل آماده می‌کند.

### API عمومی
`GET /api/public/device-models`

این endpoint بدون Login فقط اطلاعات لازم برای صفحه اولیه را برمی‌گرداند:
- brand
- model
- display_name
- thumbnail_asset
- is_verified

### Data model
`device_models.thumbnail_asset`

برای نمایش تصویر کوچک/Thumbnail هر دستگاه در جریان انتخاب اولیه استفاده می‌شود.


## Coban Full Catalog Integration — v18

MTcar now ships with a server-driven Coban device catalog.

### Traccar-verified automatic mappings
The following exact model names are preconfigured from Traccar's supported-device list:

- TK103-2B → gps103 / TCP 5001
- TK104 → gps103 / TCP 5001
- GPS-103 → gps103 / TCP 5001
- GPS-103-A → gps103 / TCP 5001
- GPS102 → gps103 / TCP 5001
- GPS102B → gps103 / TCP 5001
- GPS104 → gps103 / TCP 5001
- 306A → gps103 / TCP 5001
- GPS105B → gps103 / TCP 5001
- GPS106 → gps103 / TCP 5001
- GPS107 → gps103 / TCP 5001
- GPS301 → gps103 / TCP 5001
- GPS302 → gps103 / TCP 5001
- GPS303 → gps103 / TCP 5001
- GPS304 → gps103 / TCP 5001
- GPS305 → gps103 / TCP 5001
- GPS306 → gps103 / TCP 5001
- GPS303-G → gps103 / TCP 5001
- 303F / GPS303F → gps103 / TCP 5001
- TK303B → gps103 / TCP 5001
- TK303G → gps103 / TCP 5001
- TK103A → tk103 / TCP 5002
- TK103B → tk103 / TCP 5002

### Protocol-identification required
These are present in the MTcar catalog but intentionally do NOT receive a guessed port:

- TK106
- GPS105
- GPS311A
- 303FG
- BN-311
- G05
- GPS103B exact-name variant

For these models MTcar shows:
`نیاز به شناسایی پروتکل`

### Selection behavior
When a verified model is selected:
1. Protocol is populated.
2. Traccar port is populated.
3. TCP transport is populated.
4. Capability matrix is loaded.
5. Firmware command family is loaded.
6. Provisioning wizard can generate APN / server / GPRS setup SMS commands.
7. Unsupported UI actions are hidden or disabled.

### Provisioning API
`POST /api/device-models/:id/provisioning-plan`

Inputs:
- trackerPassword
- apn
- optional gprsUser
- optional gprsPassword

Server environment:
- `TRACKER_PUBLIC_HOST`

The returned plan includes:
- protocol
- server port
- transport
- ordered SMS setup commands

### Firmware safety
Coban command syntax varies between firmware branches.
MTcar therefore does not apply a single command profile blindly to every Coban-branded unit.

Examples:
- GPS303F documented family supports APN, adminip, GPRS and TCP/UDP switching.
- TK103A/B uses a distinct GPRS enable/disable form.
- GPS105 firmware branches can use a different APN command form.

This is why command profiles are family-specific in v18.


## AIKA / AKSH Catalog Integration — v19

### Auto-configured AKSH H02 profiles
- AKSH GT01 → h02 / TCP 5013
- AKSH LT07 → h02 / TCP 5013
- AKSH P6 → h02 / TCP 5013
- AKSH ST901 → h02 / TCP 5013

### GT06N candidate profiles
- AIKA GT06N → gt06 / TCP 5023 + first-packet verification
- AKSH GT06N → gt06 / TCP 5023 + first-packet verification

Because the same retail model name can be rebranded with different firmware,
MTcar marks these as `family_expected`, not fully verified until the first
packet decodes as GT06.

### Listed but protocol-identification required
- AIKA GT06
- AKSH GT06
- AIKA GT67
- AIKA GT76
- AIKA GT08-SA
- AIKA G902
- AIKA GT06J
- AIKA GT06W
- AKSH GT06J
- AKSH GT06W

Generic GT06 names are not forced to port 5023 because Traccar explicitly
lists generic GT06 as clones.

### UI behavior
- verified: auto protocol + port
- family_expected: prefill candidate + verify first packet
- identify_required: keep model selected, wait for packet identification

Unsupported/hardware-specific actions remain hidden until the capability
profile is known.


## Admin-Managed Device Catalog — v20

### تصمیم فعلی محصول
در نسخه فعلی فقط مدل زیر به صورت پیش‌فرض فعال است:

- MTcar MT120
- Protocol: gps103
- Port: 5001
- Transport: TCP

مدل‌های Coban / AIKA / AKSH که در v18/v19 به صورت Seed وارد شده بودند در Migration
یک‌باره غیرفعال می‌شوند.

انتخاب مدل از صفحه Login/Register نیز حذف شده است.

### مدل‌های جدید بدون APK جدید
کاتالوگ مدل‌ها اکنون Server-driven است.

مدیر از پنل مدیریت می‌تواند یک مدل جدید تعریف کند و کاربران پس از Login آن را در
`GET /api/device-models`
می‌بینند.

بنابراین اضافه‌کردن Model جدید معمولاً نیاز به انتشار APK جدید ندارد.

### فیلدهای قابل مدیریت
- Brand
- Model code
- Display name
- Thumbnail asset / URL
- Protocol
- Server port
- TCP / UDP
- Capabilities
- Command Profile
- Setup Profile
- Active / Disabled
- Verified
- Notes

### Admin API
- `GET    /api/admin/device-models`
- `POST   /api/admin/device-models`
- `PATCH  /api/admin/device-models/:id`
- `PATCH  /api/admin/device-models/:id/status`
- `DELETE /api/admin/device-models/:id`

اگر مدلی قبلاً توسط دستگاه کاربر استفاده شده باشد، حذف فیزیکی آن Block می‌شود و
باید Disable شود تا سابقه Device خراب نشود.

### App behavior
مدل‌های Active از سرور خوانده می‌شوند.
وقتی مدیر یک مدل را Active کند:
1. اپ در Refresh/Bootstrap بعدی آن را می‌گیرد.
2. کاربر آن را در انتخاب مدل Device می‌بیند.
3. Protocol / Port / Transport از همان Profile استفاده می‌شود.
4. UI قابلیت‌ها بر اساس Capability Matrix قابل کنترل است.
5. Provisioning Plan از Command Profile همان مدل ساخته می‌شود.

### Command Profile placeholders
در Command Profile می‌توان از Placeholderهای زیر استفاده کرد:
- `{password}`
- `{apn}`
- `{gprsUser}`
- `{gprsPassword}`
- `{serverHost}`
- `{serverPort}`

مثال:
`adminip{password} {serverHost} {serverPort}`

### Migration safety
کلید زیر باعث می‌شود حذف مدل‌های قدیمی فقط یک بار انجام شود:
`device_models.v20_mt120_only_migrated`

بعد از Migration، مدل‌هایی که مدیر اضافه می‌کند با Restart سرور غیرفعال نخواهند شد.


## MTcar v21 Production UI

این نسخه، UI فنی اولیه Flutter را با رابط اصلی MTcar جایگزین می‌کند:

- Login / Register / OTP / Password Reset
- هدر قرمز شیشه‌ای با لوگوی MTcar
- Light / Dark با چیدمان یکسان
- کارت اصلی خودرو و وضعیت اتصال
- دسترسی سریع: محافظت، شنود، آژیر، یافتن خودرو، قطع موتور، بازپخش مسیر، محدوده، سوخت
- Map با OSM fallback تا زمان اتصال Provider رسمی
- هشدارها
- Support Tickets
- Account / Subscription
- هشدار پایان اعتبار و هدایت به تمدید
- Trial یک‌ماهه از اولین Online واقعی
- Device onboarding بعد از Login
- MT120 به‌عنوان مدل پیش‌فرض
- Server-driven Device Catalog از پنل مدیریت
- Launcher Icon و Splash رسمی MTcar
- Android SMS backup / critical alert native overlay

### Production honesty
تا قبل از اتصال VPS، Traccar، SMS Provider، Payment Gateway و Map credentials،
بخش‌هایی که داده واقعی ندارند مقدار ساختگی نشان نمی‌دهند و با `—` یا پیام عدم دسترسی
نمایش داده می‌شوند.


## تاریخچه v22 (منسوخ) — بازگشت موقت UI

این بخش فقط تاریخچه توسعه است و مرجع فعلی UI نیست. مرجع فعلی v24 فقط پوشه `ui_reference_locked/` است.

مرجع چیدمان:
- هدر قرمز شیشه‌ای
- کارت خودروی من
- کارت اطلاعات خودرو
- دسترسی سریع چهارگانه
- بخش دستورات
- هشدارها و فعالیت‌های اخیر
- نوار پایین: خودروی من / هشدارها / سفرها / تنظیمات / حساب کاربری
- Light / Dark با ساختار یکسان

منطق Production نسخه v21 حفظ شده است:
- Login / Register / OTP / Password Reset
- MT120
- One-month first-online trial
- Subscription expiry
- Backend + Traccar
- Admin-managed device model catalog
- Android SMS backup and critical alerts


## وضعیت این بسته

این نسخه به عنوان سورس اصلی ادامه توسعه نگهداری می‌شود. مرجع قطعی UI در فایل `UI_REFERENCE_LOCKED_FA.md` و پوشه `ui_reference_locked/` ذخیره شده است.


## v24 — UI نهایی بر اساس تصاویر تأییدشده

در این نسخه، UI Flutter از روی ۱۰ تصویر مرجع قفل‌شده در پوشه `ui_reference_locked/` بازسازی شده است.

- صفحه خوش‌آمد و راه‌اندازی اولیه
- ورود و ثبت‌نام
- خانه / داشبورد
- نقشه زنده
- هشدارها و کنترل‌های امنیتی
- پشتیبانی و تیکت
- حساب کاربری
- تنظیمات دستگاه و سیم‌کارت
- پخش مسیر
- اشتراک و پرداخت

نکات فنی قبلی حفظ شده‌اند: MT120 پیش‌فرض، مدل‌های Server-driven از پنل مدیریت، Trial یک‌ماهه از اولین Online واقعی، Subscription Gate، SIM Provider، نقشه Provider، Support Tickets، Traccar، SMS Backup، Voice Monitor و Engine Safety Gate.

برای رویدادهای امنیتی، `device_events` و endpointهای مربوط به Event Log نیز اضافه شده‌اند تا صفحه هشدارها داده ساختگی نشان ندهد.
