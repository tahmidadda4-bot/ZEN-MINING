import {corsHeaders} from '../_shared/cors.ts';
import {serviceClient} from '../_shared/db.ts';

Deno.serve(async (req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders});
  try{
    const secret=Deno.env.get('REWARD_CRON_SECRET');
    if(!secret || req.headers.get('x-reward-cron-secret')!==secret)
      return Response.json({error:'Unauthorized'},{status:401,headers:corsHeaders});

    const db=serviceClient();
    const body=await req.json().catch(()=>({}));
    let q=db.from('devices').select('id,user_id,mining_status,mining_rate,mining_started_at,mining_ends_at,last_reward_at').eq('mining_status','active');
    if(body.deviceId) q=q.eq('id',body.deviceId);
    const {data:devices,error}=await q.limit(body.deviceId?1:500);
    if(error) throw error;

    const results=[];
    for(const d of devices??[]){
      if(!d.mining_started_at||!d.mining_ends_at||!d.last_reward_at) continue;
      if(new Date(d.mining_ends_at).getTime()<=Date.now()){
        await db.rpc('accrue_device_reward',{p_device_id:d.id,p_reference:`mining-complete:${d.id}:${d.mining_ends_at}`,p_amount:0});
        continue;
      }
      const elapsed=Math.max(0,(Date.now()-new Date(d.last_reward_at).getTime())/1000);
      if(elapsed<=0) continue;
      const amount=Number(d.mining_rate??0)*elapsed/86400;
      const ref=`mining:${d.id}:${new Date(d.last_reward_at).getTime()}`;
      const {data,error:e}=await db.rpc('accrue_device_reward',{p_device_id:d.id,p_reference:ref,p_amount:amount});
      if(!e) results.push({deviceId:d.id,result:data});
    }
    return Response.json({processed:results.length,results},{headers:corsHeaders});
  }catch(e){
    return Response.json({error:String(e)},{status:500,headers:corsHeaders});
  }
});
