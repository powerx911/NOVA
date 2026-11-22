import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.95.0";
const URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ORIGINS = new Set(["https://powerx911.github.io","http://localhost:3000","http://localhost:5173"]);
const cors = (origin:string|null) => ({"Access-Control-Allow-Origin":origin && ORIGINS.has(origin)?origin:"https://powerx911.github.io","Access-Control-Allow-Headers":"authorization, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin"});
const reply=(body:unknown,status:number,origin:string|null)=>new Response(JSON.stringify(body),{status,headers:{...cors(origin),"Content-Type":"application/json","Cache-Control":"no-store"}});
const service=()=>createClient(URL,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}});
const auth=()=>createClient(URL,ANON,{auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(async req=>{
 const origin=req.headers.get("Origin");
 if(origin&&!ORIGINS.has(origin)) return reply({error:"FORBIDDEN_ORIGIN"},403,origin);
 if(req.method==="OPTIONS") return new Response(null,{status:204,headers:cors(origin)});
 if(req.method!=="POST") return reply({error:"METHOD_NOT_ALLOWED"},405,origin);
 if(!URL||!ANON||!SERVICE) return reply({error:"ADMIN_AUTH_NOT_CONFIGURED"},503,origin);
 try {
  const body=await req.json().catch(()=>null);
  if(!body||typeof body.action!=="string") return reply({error:"INVALID_REQUEST"},400,origin);
  const db=service();
  if(body.action==="login") {
   const email=typeof body.email==="string"?body.email.trim().toLowerCase():"";
   const password=typeof body.password==="string"?body.password:"";
   if(!email||!password||password.length>256) return reply({error:"INVALID_CREDENTIALS"},400,origin);
   const {data,error}=await auth().auth.signInWithPassword({email,password});
   if(error||!data.user||!data.session) return reply({error:"INVALID_CREDENTIALS"},401,origin);
   const {data:account,error:lookupError}=await db.from("admin_accounts").select("role,enabled").eq("user_id",data.user.id).maybeSingle();
   if(lookupError||!account||!account.enabled||!["admin","owner"].includes(account.role)) return reply({error:"ADMIN_ACCESS_DENIED"},403,origin);
   return reply({session:{access_token:data.session.access_token,email:data.user.email,role:account.role}},200,origin);
  }
  const bearer=req.headers.get("Authorization")??"";
  const token=bearer.startsWith("Bearer ")?bearer.slice(7):"";
  if(!token) return reply({error:"UNAUTHENTICATED"},401,origin);
  const {data:userData,error:userError}=await db.auth.getUser(token);
  if(userError||!userData.user) return reply({error:"UNAUTHENTICATED"},401,origin);
  const {data:actor,error:actorError}=await db.from("admin_accounts").select("role,enabled").eq("user_id",userData.user.id).maybeSingle();
  if(actorError||!actor||!actor.enabled) return reply({error:"ADMIN_ACCESS_DENIED"},403,origin);
  if(body.action==="create_admin") {
   if(actor.role!=="owner") return reply({error:"OWNER_REQUIRED"},403,origin);
   const email=typeof body.email==="string"?body.email.trim().toLowerCase():"";
   const password=typeof body.password==="string"?body.password:"";
   if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||password.length<12||password.length>128) return reply({error:"INVALID_ADMIN_CREDENTIALS"},400,origin);
   const {data:created,error:createError}=await db.auth.admin.createUser({email,password,email_confirm:true});
   if(createError||!created.user) {
    console.error("Admin account creation failed", {code:createError?.code,status:createError?.status,message:createError?.message});
    const code=createError?.code;
    if(code==="email_exists"||code==="user_already_exists") return reply({error:"ADMIN_EMAIL_ALREADY_EXISTS"},409,origin);
    if(code==="weak_password"||code==="password_too_short") return reply({error:"ADMIN_PASSWORD_REJECTED"},400,origin);
    return reply({error:"ADMIN_ACCOUNT_CREATE_FAILED",detail:code||"AUTH_CREATE_ERROR"},409,origin);
   }
   const {error:roleError}=await db.from("admin_accounts").insert({user_id:created.user.id,role:"admin",enabled:true,created_by:userData.user.id});
   if(roleError){await db.auth.admin.deleteUser(created.user.id);return reply({error:"ADMIN_ROLE_ASSIGNMENT_FAILED"},500,origin);}
   return reply({ok:true},201,origin);
  }
  if(body.action==="list_admins") {
   if(actor.role!=="owner") return reply({error:"OWNER_REQUIRED"},403,origin);
   const {data:accounts,error:accountsError}=await db.from("admin_accounts").select("user_id,enabled,created_at").eq("role","admin").order("created_at",{ascending:false});
   if(accountsError) return reply({error:"ADMIN_LIST_FAILED"},500,origin);
   const users=[];
   for(const account of accounts??[]) {
    const {data,error}=await db.auth.admin.getUserById(account.user_id);
    if(error) { console.error("Admin listing could not resolve account",error); continue; }
    users.push({user_id:account.user_id,email:data.user?.email??"—",enabled:account.enabled,created_at:account.created_at??null});
   }
   return reply({admins:users},200,origin);
  }
  if(body.action==="delete_admin") {
   if(actor.role!=="owner") return reply({error:"OWNER_REQUIRED"},403,origin);
   const targetId=typeof body.user_id==="string"?body.user_id:"";
   if(!targetId||targetId===userData.user.id) return reply({error:"INVALID_ADMIN_TARGET"},400,origin);
   const {data:target,error:targetError}=await db.from("admin_accounts").select("user_id,role,enabled,created_by,created_at").eq("user_id",targetId).maybeSingle();
   if(targetError||!target||target.role!=="admin") return reply({error:"ADMIN_NOT_FOUND"},404,origin);
   // admin_accounts references auth.users with ON DELETE RESTRICT, so remove the role row first.
   const {error:removeRoleError}=await db.from("admin_accounts").delete().eq("user_id",targetId);
   if(removeRoleError) return reply({error:"ADMIN_DELETE_FAILED"},500,origin);
   const {error:deleteError}=await db.auth.admin.deleteUser(targetId);
   if(deleteError) {
    console.error("Admin account deletion failed",{code:deleteError.code,message:deleteError.message});
    const {error:restoreError}=await db.from("admin_accounts").insert(target);
    if(restoreError) console.error("Failed to restore admin role after deletion error",restoreError);
    return reply({error:"ADMIN_DELETE_FAILED"},500,origin);
   }
   return reply({ok:true},200,origin);
  }
  return reply({error:"UNKNOWN_ACTION"},400,origin);
 } catch(error) { console.error("Admin center request failed",error); return reply({error:"INTERNAL_ERROR"},500,origin); }
});
