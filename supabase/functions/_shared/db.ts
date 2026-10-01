import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
const url=Deno.env.get('SUPABASE_URL')!;
const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
export const userClient=(req:Request)=>createClient(url,anon,{global:{headers:{Authorization:req.headers.get('Authorization')??''}}});
export const serviceClient=():SupabaseClient=>createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
