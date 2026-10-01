# Production release

## 1. Database
Run `database/PRODUCTION.sql` once in Supabase SQL Editor.

Then create an Auth user and promote it:

```sql
update public.profiles set role='admin' where id='YOUR_AUTH_USER_UUID';
```

## 2. Supabase functions
Deploy every function under `supabase/functions/`.

Set secrets:
- `SUPABASE_SERVICE_ROLE_KEY` (Supabase-managed/secret)
- `REWARD_CRON_SECRET` (generate a long random secret)

Do not expose either secret to the web or Android app.

## 3. Reward scheduler
Call `accrue-rewards` every 5 minutes using a trusted server scheduler and header:

`x-reward-cron-secret: <REWARD_CRON_SECRET>`

The function is the only supported reward accrual path.

## 4. Android
Install Flutter SDK in the build environment, then:

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

Configure a real release keystore and keep it outside source control.

## 5. Admin
Set `admin_web/config.js` to the Supabase project URL and public key and deploy over HTTPS.

## 6. Acceptance flow
Register → login → Usage Access → register device → monitoring sync → current/closed activity → start mining → 24-hour expiry → start next cycle → wallet → withdrawal → admin approve/reject → audit.

## 7. Do not release until
- Flutter analyze/test/build pass.
- Edge Functions type-check/deploy successfully.
- `database/PRODUCTION.sql` executes without errors.
- Real-device monitoring tests pass across target Android versions/OEMs.
- Usage Access disclosure/policy requirements are satisfied.
- Payment provider is configured if real money is paid.
