import {corsHeaders} from '../_shared/cors.ts';
import {serviceClient,userClient} from '../_shared/db.ts';

Deno.serve(async req=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders});
  try{
    const auth=userClient(req);
    const u=(await auth.auth.getUser()).data.user;
    if(!u) throw new Error('Unauthorized');
    const db=serviceClient();
    const {data:p}=await db.from('profiles').select('role').eq('id',u.id).single();
    if(p?.role!=='admin') throw new Error('Admin only');
    const b=await req.json();

    if(b.action==='approve_withdrawal'){
      const {data,error}=await auth.rpc('approve_withdrawal_secure',{p_withdrawal_id:b.withdrawalId,p_admin_id:u.id});
      if(error) throw error;
      return Response.json({result:data},{headers:corsHeaders});
    }

    if(b.action==='reject_withdrawal'){
      const {data,error}=await auth.rpc('reject_withdrawal_secure',{p_withdrawal_id:b.withdrawalId,p_admin_id:u.id,p_reason:b.reason??'Rejected'});
      if(error) throw error;
      return Response.json({result:data},{headers:corsHeaders});
    }

    if(b.action==='set_mining_config'){
      const cfg=b.config??{};
      const allowed={
        global_enabled:Boolean(cfg.global_enabled),
        global_rate:Number(cfg.global_rate),
        min_withdrawal:Number(cfg.min_withdrawal),
        max_withdrawal:Number(cfg.max_withdrawal),
        withdrawal_enabled:Boolean(cfg.withdrawal_enabled),
        maintenance_mode:Boolean(cfg.maintenance_mode),
        updated_at:new Date().toISOString()
      };
      if(!Number.isFinite(allowed.global_rate)||allowed.global_rate<0) throw new Error('Invalid global rate');
      if(!Number.isFinite(allowed.min_withdrawal)||!Number.isFinite(allowed.max_withdrawal)||allowed.min_withdrawal<0||allowed.max_withdrawal<allowed.min_withdrawal) throw new Error('Invalid withdrawal limits');
      const {error}=await db.from('mining_configs').update(allowed).eq('id',b.configId);
      if(error) throw error;
      return Response.json({ok:true},{headers:corsHeaders});
    }

    if(b.action==='set_device_mining'){
      const rate=Number(b.rate);
      if(!['active','inactive','paused'].includes(b.status)||!Number.isFinite(rate)||rate<0) throw new Error('Invalid mining values');
      const patch:any={mining_status:b.status,mining_rate:rate,updated_at:new Date().toISOString()};
      if(b.status==='active'){
        const now=new Date();
        patch.mining_started_at=now.toISOString();
        patch.mining_ends_at=new Date(now.getTime()+24*60*60*1000).toISOString();
        patch.last_reward_at=now.toISOString();
      }else{
        patch.mining_ends_at=null;
      }
      const {error}=await db.from('devices').update(patch).eq('id',b.deviceId);
      if(error) throw error;
      await db.from('admin_audit_logs').insert({admin_id:u.id,action:'set_device_mining',entity_type:'device',entity_id:b.deviceId,metadata:{status:b.status,rate}});
      return Response.json({ok:true},{headers:corsHeaders});
    }

    throw new Error('Unknown action');
  }catch(e){
    return Response.json({error:String(e)},{status:400,headers:corsHeaders});
  }
});
