# ZEN MINING — Production Source Package

This package contains the production-oriented source for:

- `user_app/` — Flutter Android user app
- `admin_web/` — static Admin Panel
- `supabase/functions/` — server-side API / reward / monitoring sync
- `database/PRODUCTION.sql` — Supabase PostgreSQL schema and security functions
- `docs/` — release and QA documentation

## Final architecture

### Monitoring
The user explicitly grants Android Usage Access. The monitoring component records only application usage metadata:

- package/app name
- foreground session start
- foreground session end when available
- duration
- current/open session
- last sync / last seen

It does **not** read messages, passwords, page contents, files, or private app content.

The User App does not expose monitoring history to the user. Monitoring is an Admin-only management surface.

### Reward
Mining is independent of monitoring. A user explicitly starts a server-authoritative 24-hour reward cycle. The server stores:

- `mining_started_at`
- `mining_ends_at`
- `last_reward_at`
- `mining_rate`
- wallet ledger entries

After 24 hours, the server automatically marks the cycle inactive. A later start begins a new cycle.

## Database

Use `database/PRODUCTION.sql` in Supabase SQL Editor.

Create the first Auth user in Supabase, then promote it:

```sql
update public.profiles
set role='admin'
where id='YOUR_AUTH_USER_UUID';
```

Never place the Supabase service-role key in Flutter or the browser.

## Edge Functions

Deploy:

- `register-device`
- `heartbeat`
- `sync-device-activity`
- `sync-activity`
- `request-withdrawal`
- `admin-action`
- `admin-dashboard`
- `accrue-rewards`

`accrue-rewards` is intentionally protected by `REWARD_CRON_SECRET`. It must be invoked only by a trusted scheduler.

## Flutter

The repository contains the application source and Android-specific monitoring code. A complete Flutter host must be generated/maintained with the Flutter SDK because the SDK owns Gradle/plugin boilerplate.

Run:

```bash
cd user_app
flutter create --org com.zenmining --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

If `flutter create` is used on an existing directory, preserve the supplied Kotlin source and manifest.

## Admin Web

Set `admin_web/config.js`:

```js
window.ZEN_CONFIG={
  supabaseUrl:"https://YOUR_PROJECT.supabase.co",
  supabaseAnonKey:"YOUR_PUBLIC_KEY"
};
```

Serve `admin_web/` from a static HTTPS host.

## Required real-device QA

Before release, test at minimum:

1. Android Usage Access grant/revoke.
2. Current foreground app appears in Admin.
3. Open activity duration updates.
4. Closed activity gets an end time.
5. User does not reopen ZEN MINING on the next day; monitoring remains active when Android permits it.
6. Device reboot and monitoring recovery.
7. Battery optimization / OEM restrictions.
8. User stops the monitoring foreground service.
9. 24-hour mining expires without opening the app.
10. Starting a new mining cycle after expiry.
11. Duplicate activity sync does not create duplicate sessions.
12. Withdrawal lock, request, approve, reject and wallet ledger.
13. Admin authorization and audit log.
14. Offline device / delayed sync behavior.

## Android / store policy

Usage Access and background monitoring are sensitive capabilities. The production release must use a clear, user-visible consent explanation and satisfy the target distribution platform's current policy/disclosure requirements. Do not attempt to hide the monitoring component or survive an uninstall.

## Real-money withdrawals

Real payout requires a real payment provider, verified merchant account, server-side credentials, reconciliation, fraud controls, failure/retry handling and compliance checks. The source package does not contain payment credentials.
