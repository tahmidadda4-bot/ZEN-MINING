# QA

## Static checks completed for this source package

- All JavaScript files pass Node syntax checking where applicable.
- Flutter source was reviewed for missing server RPC names and updated to use the production RPCs.
- SQL includes the required tables, columns, RLS policies and server-side RPCs used by the Flutter/Edge Function code.
- Reward scheduler is protected by a server secret.
- Device activity sync uses a hashed per-device monitor token and idempotent session keys.
- Current foreground sessions are represented as open activity records and upserted rather than duplicated.
- 24-hour mining is server-authoritative and automatically expires.
- User device registration no longer silently starts mining.

## Checks that must run in a real build environment

This container does not include Flutter/Dart, Deno or PostgreSQL client tooling, so a truthful final statement of successful compilation/deployment cannot be made here.

Run:

```bash
flutter analyze
flutter test
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

For Edge Functions, run the current Supabase/Deno type check/deploy commands in the project environment.

Run the SQL in a disposable Supabase project before production.

## Important Android behavior

Android/OEM background restrictions can interrupt monitoring. The Admin Panel must therefore show `last_seen_at`, `monitoring_last_sync_at`, and permission/monitoring state instead of claiming guaranteed continuous capture.

Uninstall must remove the normal app. The system must not use hidden persistence to survive uninstall.
