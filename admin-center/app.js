const API_URL = "https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/admin-center";
let accessToken = "";
const $ = (selector) => document.querySelector(selector);
function message(text, error = false) { $("#feedback").textContent = text; $("#feedback").dataset.error = String(error); }
async function api(action, data = {}) {
 const response = await fetch(API_URL, { method:"POST", headers:{"Content-Type":"application/json", ...(accessToken ? {Authorization:`Bearer ${accessToken}`} : {})}, body:JSON.stringify({action,...data}) });
 const result = await response.json().catch(()=>({}));
 if (!response.ok) throw new Error(result.error || "تعذر إكمال الطلب.");
 return result;
}
function show(session) {
 accessToken = session.access_token;
 $("#login-panel").hidden = true; $("#app-panel").hidden = false;
 $("#owner-panel").hidden = session.role !== "owner";
 $("#session-label").textContent = `${session.email} · ${session.role === "owner" ? "Owner" : "Admin"}`;
 $("#notice").hidden = false; $("#notice").textContent = "تم التحقق من صلاحية الحساب على الخادم.";
}
$("#login-form").addEventListener("submit", async e => {
 e.preventDefault(); const f = new FormData(e.currentTarget);
 try { show((await api("login",{email:f.get("email"),password:f.get("password")})).session); message(""); }
 catch(err) { message(err.message,true); }
});
$("#create-admin-form").addEventListener("submit", async e => {
 e.preventDefault(); const form = e.currentTarget;
 if (!accessToken || $("#owner-panel").hidden) return;
 const f = new FormData(form);
 try { await api("create_admin",{email:f.get("email"),password:f.get("password")}); form.reset(); message("تم إنشاء حساب Admin."); }
 catch(err) { message(err.message,true); }
});
$("#logout-button").addEventListener("click",()=>{accessToken="";$("#app-panel").hidden=true;$("#login-panel").hidden=false;$("#owner-panel").hidden=true;message("تم تسجيل الخروج.");});
