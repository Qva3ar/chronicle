# Chrono 1.0.21 (22) — store release

Marketing version `1.0.21`, build `22`. Android and iOS both take these from `pubspec.yaml`.

## What's New — App Store / Play (EN)

```
Sunrise and sunset routines
Tie a routine to sunrise or sunset instead of a clock time. For example: every Friday, an hour before sunset, with reminders every 10 minutes.

Your location comes from your timezone, so it works right away without any permission. Prefer an exact match? Switch to GPS in Settings. Times stay on your device and are never sent anywhere, and a small calibration lets you match your local timetable.

Also in this update
• Routine reminders now fire at the exact time instead of being batched overnight
• Play Billing Library 8, required for updates after August 31, 2026
• Productivity history now includes archived goals and routines so past scores still add up
```

## Что нового (RU)

```
Рутины по восходу и закату
Рутину можно привязать к восходу или закату, а не к часам. Например: каждую пятницу за час до заката, с напоминаниями каждые 10 минут.

Местоположение берётся из часового пояса, поэтому всё работает сразу и без разрешений. Нужна точность — включите GPS в Настройках. Данные остаются на устройстве и никуда не отправляются, а калибровка поможет подогнать время под ваше расписание.

Ещё в этом обновлении
• Напоминания рутин приходят в точное время, а не пачкой утром
• Play Billing Library 8 — требование Google с 31 августа 2026
• В истории продуктивности учитываются архивные цели и рутины, чтобы старые оценки сходились
```

Play Console release notes are capped at 500 characters. The English block above is ~620 — use this shorter variant if the form rejects it:

```
Sunrise and sunset routines: tie a habit to sunrise or sunset (e.g. an hour before sunset every Friday). Works straight away from your timezone, no permission needed; GPS is optional. Routine reminders now fire on time. Also: Play Billing 8 and a productivity-history fix for archived items.
```

```
Рутины по восходу и закату: привычку можно привязать к солнцу (например, за час до заката по пятницам). Работает сразу по часовому поясу, без разрешений; GPS — по желанию. Напоминания теперь приходят вовремя. Ещё: Play Billing 8 и исправление истории продуктивности.
```

## Store questionnaires

By default Chrono never touches a location API: coordinates are looked up from the device timezone in a bundled table. GPS is opt-in and, either way, coordinates never leave the device.

### App Store Connect → App Privacy

If Apple's form treats on-device-only access as collection, declare:

| Field | Value |
|-------|--------|
| Data type | Location → Coarse Location |
| Linked to identity | No |
| Used for tracking | No |
| Purposes | App Functionality |
| Collected from this app | Yes, if the form has no “stays on device” option |

If the form lets you say the data is not transmitted off device, you can leave Location undeclared. Keep `NSLocationWhenInUseUsageDescription` either way — it is already in `Info.plist`.

Do **not** add Precise Location, do **not** add “Used for tracking”.

After submitting, update the privacy policy URL if the hosted copy is not this repo's `privacy_policy.html` (Last Updated: September 19, 2026).

### Google Play → Data safety

Same rule: Play asks what you *collect* (send off the device). Approximate location stays local, so it is typically **not collected** and **not shared**.

Still expect a review question because `ACCESS_COARSE_LOCATION` is in the manifest. Answer:

- Permission is optional and used only to compute sunrise/sunset on device.
- The default path derives coordinates from the device timezone, so most users never grant it.
- Data is not transmitted, not sold, not used for ads.

Play Billing Library is now 8.0.0 (required for updates after 31 Aug 2026). No listing change besides the version.

## Reviewer notes (optional paste)

Chrono can schedule a routine relative to local sunrise or sunset. That needs an approximate location. The app:

1. Derives it from the device timezone by default, using a bundled table of representative coordinates from the tz database. No permission, no location API call.
2. Asks for coarse location only if the user explicitly taps “Use GPS for an exact match”.

A single low-accuracy reading is stored in SharedPreferences and used for an offline astronomical calculation (`daylight`). Nothing is sent to a server.

## Build (when you are ready to upload)

```
flutter clean && flutter pub get
flutter build appbundle --release          # Play: build/app/outputs/bundle/release/app-release.aab
flutter build ipa --release                # App Store: build/ios/ipa/*.ipa
```

iOS can also be archived from Xcode as usual; version/build come from Flutter (`1.0.21` / `22`).
