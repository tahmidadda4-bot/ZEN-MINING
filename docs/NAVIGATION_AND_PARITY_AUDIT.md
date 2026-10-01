# Navigation & Screen Parity Audit

## User App
- Splash -> Welcome -> Register/Login -> Permissions -> Home shell.
- Home shell contains Home, Mining, Wallet, Profile tabs.
- Wallet -> Withdraw.
- Profile -> Device Information, Notifications, Settings.
- System Back is preserved through the Flutter Navigator stack during onboarding; successful permission setup intentionally replaces the onboarding stack with Home so old auth pages are not reachable.
- Home is a root screen and therefore Android Back does not accidentally pop the whole app route; the app remains on Home.

## Admin Web
- Dashboard, Users, Devices, Activity, Mining, Wallets, Withdrawals, Transactions, Earnings, Reports, Notifications, Settings are all present.
- Navigation uses browser hash history. Browser Back/Forward changes the SPA section instead of closing the tab.
- Logout remains the explicit action that ends the authenticated admin session.

## Functional parity
| User feature | Admin counterpart |
|---|---|
| Device information | Devices |
| Current/previous app activity | Activity |
| Mining status/rate | Mining |
| Wallet/balance | Wallets |
| Withdrawal | Withdrawals |
| Notifications | Notifications |
| Settings/configuration | Settings |
| Account/profile | Users/Admin Account |

User-only screens such as personal settings are not duplicated as admin screens; the admin controls the corresponding system-level configuration.

## Release checks
- Run `node --check admin_web/app.js`.
- Run `flutter analyze` and `flutter test` from `user_app/` with Flutter SDK installed.
- Run `flutter build appbundle --release` with production dart-defines.
- Test Android Back on every onboarding/detail screen and browser Back/Forward in Admin.

## Code fixes in this audit
- Fixed Flutter native monitoring service method-channel call to use the declared channel.
- Added User App bottom navigation for Home/Mining/Wallet/Profile.
- Preserved onboarding back navigation and made Home a non-pop root.
- Added Admin browser history navigation and expanded Activity with start/end/duration/status.
