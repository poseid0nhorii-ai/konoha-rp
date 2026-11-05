import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const headers={ "Access-Control-Allow-Origin":"*", "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods":"POST, OPTIONS" };
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...headers,"Content-Type":"application/json"}});
serve(async req=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers});
  if(req.method!=="POST")return json({error:"Méthode non autorisée"},405);
  const token=req.headers.get("Authorization")?.replace(/^Bearer\s+/i,"").trim();
  if(!token)return json({error:"Authentification requise"},401);
  const url=Deno.env.get("SUPABASE_URL"),serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!url||!serviceKey)return json({error:"Configuration serveur incomplète"},500);
  const supabase=createClient(url,serviceKey,{auth:{autoRefreshToken:false,persistSession:false}});
  const {data:{user},error:userError}=await supabase.auth.getUser(token);
  if(userError||!user)return json({error:"Session invalide"},401);
  const {data:admin,error:adminErr}=await supabase.from("profiles").select("id,role,approved").eq("id",user.id).maybeSingle();
  if(adminErr||admin?.role!=="admin"||!admin.approved)return json({error:"Accès administrateur refusé"},403);
  try {
    const body=await req.json();
    const email=String(body.email||"").trim().toLowerCase();
    const nickname=String(body.nickname||"").trim();
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||nickname.length<2||nickname.length>60)return json({error:"E-mail ou nom RP invalide"},400);
    const {error}=await supabase.auth.admin.inviteUserByEmail(email,{data:{nickname}});
    if(error)return json({error:error.message},400);
    return json({ok:true});
  } catch{return json({error:"Requête invalide"},400)}
});