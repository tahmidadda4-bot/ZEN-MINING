import { corsHeaders } from '../_shared/cors.ts';
import { serviceClient, userClient } from '../_shared/db.ts';

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(hash))
    .map((x) => x.toString(16).padStart(2, '0'))
    .join('');
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  try {
    return JSON.stringify(error);
  } catch (_) {
    return 'Device registration failed';
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const auth = userClient(req);
    const user = (await auth.auth.getUser()).data.user;
    if (!user) {
      return Response.json(
        { error: 'Unauthorized' },
        { status: 401, headers: corsHeaders },
      );
    }

    const body = await req.json();
    if (!body.deviceFingerprint || !body.deviceName) {
      throw new Error('deviceFingerprint and deviceName are required');
    }

    const db = serviceClient();
    const { data: existing, error: lookupError } = await db
      .from('devices')
      .select('*')
      .eq('device_fingerprint', body.deviceFingerprint)
      .maybeSingle();

    if (lookupError) throw lookupError;
    if (existing && existing.user_id !== user.id) {
      throw new Error('This device is already registered to another account.');
    }

    // Use the first config row if present; keep a safe default if no row exists yet.
    const { data: cfg, error: cfgError } = await db
      .from('mining_configs')
      .select('global_rate')
      .limit(1)
      .maybeSingle();

    if (cfgError) throw cfgError;

    const monitorToken = `zm_${crypto.randomUUID()}_${crypto.randomUUID().replaceAll('-', '')}`;
    const tokenHash = await sha256(monitorToken);
    const miningRate = Number(cfg?.global_rate ?? 5);

    let data;
    let error;

    if (existing) {
      ({ data, error } = await db
        .from('devices')
        .update({
          device_name: body.deviceName,
          model: body.model ?? null,
          android_version: body.androidVersion ?? null,
          app_version: body.appVersion ?? null,
          status: 'online',
          last_seen_at: new Date().toISOString(),
          monitor_token_hash: tokenHash,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id)
        .select()
        .single());
    } else {
      ({ data, error } = await db
        .from('devices')
        .insert({
          user_id: user.id,
          device_fingerprint: body.deviceFingerprint,
          device_name: body.deviceName,
          model: body.model ?? null,
          android_version: body.androidVersion ?? null,
          app_version: body.appVersion ?? null,
          status: 'online',
          last_seen_at: new Date().toISOString(),
          monitor_token_hash: tokenHash,
          mining_status: 'inactive',
          mining_rate: miningRate,
          mining_started_at: null,
          mining_ends_at: null,
          last_reward_at: null,
        })
        .select()
        .single());
    }

    if (error) throw error;

    return Response.json(
      { device: data, monitorToken },
      { headers: corsHeaders },
    );
  } catch (error) {
    return Response.json(
      { error: errorMessage(error) },
      { status: 400, headers: corsHeaders },
    );
  }
});
