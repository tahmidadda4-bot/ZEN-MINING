import { corsHeaders } from '../_shared/cors.ts';
import { serviceClient, userClient } from '../_shared/db.ts';

Deno.serve(async (req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders});
 try{
  const auth=userClient(req);
  const {data:{user}}=await auth.auth.getUser();
  if(!user) throw new Error('Unauthorized');
  const db=serviceClient();
  const {data:profile}=await db.from('profiles').select('role').eq('id',user.id).single();
  if(profile?.role!=='admin') throw new Error('Admin only');

  const [{data:devices},{data:wallets},{data:withdrawals},{data:activities},{data:transactions},{data:config}]=await Promise.all([
   db.from('devices').select('*').order('last_seen_at',{ascending:false}),
   db.from('wallets').select('*'),
   db.from('withdrawals').select('*').order('requested_at',{ascending:false}).limit(100),
   db.from('device_activities').select('*').order('started_at',{ascending:false}).limit(200),
   db.from('reward_transactions').select('*').order('created_at',{ascending:false}).limit(200),
   db.from('mining_configs').select('*').limit(1).single()
  ]);
  return Response.json({devices,wallets,withdrawals,activities,transactions,config},{headers:corsHeaders});
 }catch(e){return Response.json({error:String(e)},{status:403,headers:corsHeaders});}
});
