const API_URL = "https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/admin-center";
let accessToken = "";\nconst SESSION_KEY = "nova_admin_session";\nfunction saveSession(session) { accessToken=session.access_token; localStorage.setItem(SESSION_KEY,JSON.stringify({refresh_token:session.refresh_token,email:session.email,role:session.role})); }\nfunction clearSession() { accessToken=""; localStorage.removeItem(SESSION_KEY); }
const $ = (selector) => document.querySelector(selector);
function message(text, error = false) { $("#feedback").textContent = text; $("#feedback").dataset.error = String(error); }
function explain(code) {
 const messages = {
  ADMIN_EMAIL_ALREADY_EXISTS:"هذا البريد الإلكتروني مسجل مسبقًا.",
  ADMIN_PASSWORD_REJECTED:"كلمة المرور مرفوضة من إعدادات المصادقة. جرّب كلمة مرور أقوى.",
  ADMIN_ACCOUNT_CREATE_FAILED:"تعذر إنشاء الحساب في Supabase Auth. راجع سجل Edge Function لمعرفة سبب الرفض.",
  ADMIN_ROLE_ASSIGNMENT_FAILED:"تم إنشاء المستخدم لكن تعذر إسناد صلاحية Admin؛ راجع سجل Edge Function.",
  ADMIN_LIST_FAILED:"تعذر تحميل قائمة الأدمن.",
  ADMIN_DELETE_FAILED:"تعذر حذف حساب الأدمن.",
  ADMIN_NOT_FOUND:"حساب الأدمن غير موجود.",
  OWNER_REQUIRED:"هذه العملية متاحة للأونر فقط."
 };
 return messages[code] || code || "تعذر إكمال الطلب.";
}
async function api(action, data = {}) {
 const response = await fetch(API_URL, { method:"POST", headers:{"Content-Type":"application/json", ...(accessToken ? {Authorization:`Bearer ${accessToken}`} : {})}, body:JSON.stringify({action,...data}) });
 const result = await response.json().catch(()=>({}));
 if (!response.ok) throw new Error(explain(result.error));
 return result;
}
function show(session) {
 saveSession(session);
 $("#login-panel").hidden = true; $("#app-panel").hidden = false;
 $("#owner-panel").hidden = session.role !== "owner";
 $("#session-label").textContent = `${session.email} · ${session.role === "owner" ? "Owner" : "Admin"}`;
 $("#notice").hidden = false; $("#notice").textContent = "تم التحقق من صلاحية الحساب على الخادم.";
 if(session.role==="owner") loadAdmins();
}
async function loadAdmins() {
 const list=$("#admin-list");
 list.replaceChildren();
 const loading=document.createElement("p"); loading.className="muted"; loading.textContent="جارٍ تحميل الحسابات…"; list.append(loading);
 try {
  const {admins=[]}=await api("list_admins");
  list.replaceChildren();
  if(!admins.length){const empty=document.createElement("p");empty.className="muted";empty.textContent="لا توجد حسابات Admin حاليًا.";list.append(empty);return;}
  for(const admin of admins) {
   const row=document.createElement("div");row.className="admin-row";
   const info=document.createElement("div");info.className="admin-info";
   const email=document.createElement("strong");email.textContent=admin.email;
   const status=document.createElement("span");status.textContent=admin.enabled?"مفعّل":"معطّل";
   info.append(email,status);
   const remove=document.createElement("button");remove.type="button";remove.className="danger";remove.textContent="حذف";
   remove.addEventListener("click",async()=>{
    if(!window.confirm(`تأكيد حذف حساب الأدمن ${admin.email}؟ لا يمكن التراجع عن الحذف.`)) return;
    remove.disabled=true;
    try {await api("delete_admin",{user_id:admin.user_id});message("تم حذف حساب الأدمن.");await loadAdmins();}
    catch(err){message(err.message,true);remove.disabled=false;}
   });
   row.append(info,remove);list.append(row);
  }
 } catch(err){list.replaceChildren();const error=document.createElement("p");error.className="muted";error.textContent=err.message;list.append(error);}
}
async function restoreSession() {\n const saved=localStorage.getItem(SESSION_KEY); if(!saved) return;\n try { const parsed=JSON.parse(saved); const result=await api("refresh_session",{refresh_token:parsed.refresh_token}); show(result.session); message(""); }\n catch { clearSession(); $("#app-panel").hidden=true; $("#login-panel").hidden=false; }\n}\n$("#login-form").addEventListener("submit", async e => {
 e.preventDefault(); const f = new FormData(e.currentTarget);
 try { show((await api("login",{email:f.get("email"),password:f.get("password")})).session); message(""); }
 catch(err) { message(err.message,true); }
});
$("#create-admin-form").addEventListener("submit", async e => {
 e.preventDefault(); const form = e.currentTarget;
 if (!accessToken || $("#owner-panel").hidden) return;
 const f = new FormData(form);
 try { await api("create_admin",{email:f.get("email"),password:f.get("password")}); form.reset(); message("تم إنشاء حساب Admin."); await loadAdmins(); }
 catch(err) { message(err.message,true); }
});
$("#refresh-admins").addEventListener("click",loadAdmins);
$("#logout-button").addEventListener("click",()=>{clearSession();$("#app-panel").hidden=true;$("#login-panel").hidden=false;$("#owner-panel").hidden=true;message("تم تسجيل الخروج.");});
\nrestoreSession();\n