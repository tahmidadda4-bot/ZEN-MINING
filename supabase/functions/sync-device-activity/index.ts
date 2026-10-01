import {corsHeaders} from '../_shared/cors.ts';
import {serviceClient} from '../_shared/db.ts';

async function sha256(value:string){
  const b=new TextEncoder().encode(value);
  const h=await crypto.subtle.digest('SHA-256',b);
  return Array.from(new Uint8Array(h)).map(x=>x.toString(16).padStart(2,'0')).join('');
}

Deno.serve(async req=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders});
  try{
    const b=await req.json();
    if(typeof b.monitorToken!=='string'||!Array.isArray(b.activities)) throw new Error('Invalid payload');
    if(b.activities.length>200) throw new Error('Too many activity records');
    const hash=await sha256(b.monitorToken);
    const db=serviceClient();
    const {data:device,error:de}=await db.from('devices')
      .select('id').eq('monitor_token_hash',hash).maybeSingle();
    if(de||!device) throw new Error('Invalid device token');

    const rows=b.activities.slice(0,200).map((x:any)=>{
      const started=String(x.startedAt);
      const ended=x.endedAt?String(x.endedAt):null;
      const key=String(x.sessionKey||`${String(x.packageName)}:${started}`);
      const duration=Math.max(0,Math.min(Number(x.durationSeconds??0),86400));
      return {
        device_id:device.id, session_key:key,
        package_name:String(x.packageName).slice(0,255),
        app_name:String(x.appName??x.packageName).slice(0,255),
        started_at:started, ended_at:ended, duration_seconds:duration,
        updated_at:new Date().toISOString()
      };
    });

    for(const row of rows){
      const {error}=await db.from('device_activities').upsert(row,{onConflict:'device_id,session_key'});
      if(error) throw error;
    }

    await db.from('devices').update({
      status:'online',
      monitoring_last_sync_at:new Date().toISOString(),
      last_seen_at:new Date().toISOString(),
      updated_at:new Date().toISOString()
    }).eq('id',device.id);

    return Response.json({accepted:rows.length},{headers:corsHeaders});
  }catch(e){
    return Response.json({error:String(e)},{status:400,headers:corsHeaders});
  }
});
