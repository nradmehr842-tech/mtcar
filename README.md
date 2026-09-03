# MTcar — Android first test build

This repository is the build-ready first Android test client for MTcar.

## Included screens
- Login / registration / SMS verification demo
- First-run tracker setup
- My Car dashboard
- Light / dark mode
- Persian / English switch
- Map and «بازپخش مسیر» with date/time range and replay controls
- Security alerts
- Car siren / protection / engine-cut safety confirmation
- Live audio monitor flow
- Support tickets UI
- User account
- Device settings: model, IMEI, tracker SIM, operator and device status
- SIM balance/data status, top-up and data package purchase UI
- Annual subscription and payment history UI

## Important test-build behavior
The VPS and production provider APIs are not live yet, so server-dependent values use safe demo states. SIM balance/data never show a fabricated live value; they show unavailable until a real provider is connected.

The Android bridge includes a tracker SMS/dial flow for Monitor Mode. If SEND_SMS permission has not been granted, Android opens the SMS composer instead of silently sending the command.

## APK build
GitHub Actions workflow: `.github/workflows/build-apk.yml`

It builds `mobile/build/app/outputs/flutter-apk/app-debug.apk` using Flutter 3.35.5.

Production release signing is intentionally not included in this first test build. A permanent signing key should be generated and stored securely before public distribution.
