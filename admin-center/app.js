const API_URL = "https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/admin-center";
let accessToken = "";
const SESSION_KEY = "nova_admin_session";
const $ = (selector) => document.querySelector(selector);
const STATUS_LABELS = { open: "مفتوح", reviewing: "قيد المراجعة", closed: "مغلق" };
const REASON_LABELS = { harassment: "مضايقة", spam: "رسائل مزعجة", inappropriate: "محتوى غير مناسب", impersonation: "انتحال شخصية", other: "سبب آخر" };
const ACTION_LABELS = {
 admin_account_created: "إنشاء حساب مشرف",
 admin_account_deleted: "حذف حساب مشرف",
 admin_report_status_changed: "تحديث حالة بلاغ لاعب"
};
function saveSession(session) {
 accessToken = session.access_token;
 localStorage.setItem(SESSION_KEY, JSON.stringify({ refresh_token: session.refresh_token, email: session.email, role: session.role }));
}
function clearSession() { accessToken = ""; localStorage.removeItem(SESSION_KEY); }
function message(text, error = false) {
 $("#feedback").textContent = text;
 $("#feedback").dataset.error = String(error);
}
function explain(code) {
 const messages = {
  ADMIN_EMAIL_ALREADY_EXISTS: "هذا البريد الإلكتروني مسجل مسبقًا.",
  ADMIN_PASSWORD_REJECTED: "كلمة المرور مرفوضة من إعدادات المصادقة. جرّب كلمة مرور أقوى.",
  ADMIN_ACCOUNT_CREATE_FAILED: "تعذر إنشاء الحساب في Supabase Auth.",
  ADMIN_ROLE_ASSIGNMENT_FAILED: "تم إنشاء المستخدم لكن تعذر إسناد صلاحية Admin.",
  ADMIN_LIST_FAILED: "تعذر تحميل قائمة الأدمن.",
  ADMIN_DELETE_FAILED: "تعذر حذف حساب الأدمن.",
  ADMIN_NOT_FOUND: "حساب الأدمن غير موجود.",
  OWNER_REQUIRED: "هذه العملية متاحة للأونر فقط.",
  REPORT_LIST_FAILED: "تعذر تحميل البلاغات.",
  INVALID_REPORT_UPDATE: "أدخل سببًا واضحًا للإجراء (8 أحرف على الأقل) واختر حالة صحيحة.",
  REPORT_NOT_FOUND: "البلاغ غير موجود أو تم حذفه.",
  REPORT_UPDATE_FAILED: "تعذر تحديث حالة البلاغ.",
  PLAYER_SEARCH_TOO_SHORT: "اكتب حرفين على الأقل للبحث.",
  PLAYER_SEARCH_FAILED: "تعذر البحث عن اللاعبين.",
  ADMIN_ACTIVITY_FAILED: "تعذر تحميل سجل الإجراءات.",
  AUDIT_LOG_WRITE_FAILED: "تعذر حفظ سجل التدقيق؛ لم يكتمل الإجراء."
 };
 return messages[code] || code || "تعذر إكمال الطلب.";
}
async function api(action, data = {}) {
 const response = await fetch(API_URL, {
  method: "POST",
  headers: { "Content-Type": "application/json", ...(accessToken ? { Authorization: "Bearer " + accessToken } : {}) },
  body: JSON.stringify({ action, ...data })
 });
 const result = await response.json().catch(() => ({}));
 if (!response.ok) {
  const error = new Error(explain(result.error));
  error.status = response.status;
  error.code = result.error || "REQUEST_FAILED";
  throw error;
 }
 return result;
}
function node(tag, className, text) {
 const item = document.createElement(tag);
 if (className) item.className = className;
 if (text !== undefined) item.textContent = text;
 return item;
}
function dateLabel(value) {
 if (!value) return "—";
 const date = new Date(value);
 return Number.isNaN(date.getTime()) ? "—" : date.toLocaleString("ar", { dateStyle: "medium", timeStyle: "short" });
}
function switchView(name) {
 document.querySelectorAll(".view").forEach(view => view.classList.toggle("active", view.id === "view-" + name));
 document.querySelectorAll("[data-view]").forEach(button => button.classList.toggle("active", button.dataset.view === name));
 const titles = { overview: "نظرة عامة", reports: "بلاغات اللاعبين", players: "إدارة اللاعبين", activity: "سجل الإجراءات", admins: "حسابات المشرفين" };
 $("#page-title").textContent = titles[name] || "مركز الإدارة";
 if (name === "overview") loadOverview();
 if (name === "reports") loadReports();
 if (name === "activity") loadActivity();
}
function show(session) {
 saveSession(session);
 $("#login-panel").hidden = true;
 $("#app-panel").hidden = false;
 document.querySelectorAll(".owner-nav").forEach(item => item.hidden = session.role !== "owner");
 $("#session-label").textContent = session.email + " · " + (session.role === "owner" ? "Owner" : "Admin");
 $("#notice").hidden = false;
 $("#notice").textContent = "تم التحقق من صلاحية الحساب على الخادم.";
 switchView("overview");
 if (session.role === "owner") loadAdmins();
}
async function loadOverview() {
 try {
  const [{ reports = [] }, { events = [] }] = await Promise.all([
   api("list_player_reports"), api("list_admin_activity")
  ]);
  $("#stat-open").textContent = reports.filter(item => item.status === "open").length;
  $("#stat-reviewing").textContent = reports.filter(item => item.status === "reviewing").length;
  $("#stat-activity").textContent = events.length;
 } catch (error) { message(error.message, true); }
}
async function loadReports() {
 const list = $("#reports-list");
 list.replaceChildren(node("p", "muted", "جارٍ تحميل البلاغات…"));
 try {
  const { reports = [] } = await api("list_player_reports");
  list.replaceChildren();
  if (!reports.length) {
   list.append(node("p", "empty-state", "لا توجد بلاغات لاعبين حاليًا."));
   return;
  }
  for (const report of reports) {
   const card = node("article", "report-card");
   const head = node("div", "report-head");
   const title = node("strong", "", report.reporter_name + " أبلغ عن " + report.target_name);
   const badge = node("span", "status-badge status-" + report.status, STATUS_LABELS[report.status] || report.status);
   head.append(title, badge);
   const meta = node("p", "report-meta", (REASON_LABELS[report.reason] || report.reason) + " · " + dateLabel(report.created_at));
   const ids = node("p", "report-ids", "المبلّغ: " + report.reporter_uid + " · اللاعب المبلّغ عنه: " + report.target_uid);
   const controls = node("div", "report-controls");
   const status = node("select", "status-select");
   for (const value of ["open", "reviewing", "closed"]) {
    const option = node("option", "", STATUS_LABELS[value]);
    option.value = value;
    status.append(option);
   }
   status.value = report.status;
   const reason = node("input", "reason-input");
   reason.type = "text";
   reason.maxLength = 500;
   reason.placeholder = "سبب تحديث حالة البلاغ (إلزامي)";
   const save = node("button", "small-button", "حفظ الإجراء");
   save.type = "button";
   save.addEventListener("click", async () => {
    save.disabled = true;
    try {
     await api("update_player_report", { report_id: report.id, status: status.value, reason: reason.value });
     message("تم تحديث البلاغ وتسجيل الإجراء.");
     await loadReports();
     await loadOverview();
    } catch (error) { message(error.message, true); save.disabled = false; }
   });
   controls.append(status, reason, save);
   card.append(head, meta, ids, controls);
   list.append(card);
  }
 } catch (error) {
  list.replaceChildren(node("p", "error-state", error.message));
  message(error.message, true);
 }
}
async function loadPlayers(query) {
 const list = $("#players-list");
 list.replaceChildren(node("p", "muted", "جارٍ البحث…"));
 try {
  const { players = [] } = await api("search_players", { query });
  list.replaceChildren();
  if (!players.length) { list.append(node("p", "empty-state", "لم يتم العثور على لاعبين مطابقين.")); return; }
  for (const player of players) {
   const card = node("article", "player-card");
   const heading = node("div", "player-heading");
   heading.append(node("strong", "", player.username), node("span", "pill", "المستوى " + player.level));
   const uid = node("p", "report-ids", "معرّف الحساب: " + player.user_id);
   const stats = node("div", "player-stats");
   stats.append(
    node("span", "", "الرصيد: " + Number(player.wallet_balance || 0).toLocaleString("ar")),
    node("span", "", "الخبرة: " + Number(player.xp || 0).toLocaleString("ar")),
    node("span", "", "السمعة: " + Number(player.reputation || 0).toLocaleString("ar")),
    node("span", "", "النفوذ: " + Number(player.influence || 0).toLocaleString("ar"))
   );
   card.append(heading, uid, stats);
   list.append(card);
  }
 } catch (error) {
  list.replaceChildren(node("p", "error-state", error.message));
  message(error.message, true);
 }
}
async function loadActivity() {
 const list = $("#activity-list");
 list.replaceChildren(node("p", "muted", "جارٍ تحميل سجل الإجراءات…"));
 try {
  const { events = [] } = await api("list_admin_activity");
  list.replaceChildren();
  if (!events.length) { list.append(node("p", "empty-state", "لا توجد إجراءات إدارية مسجلة بعد.")); return; }
  for (const event of events) {
   const card = node("article", "activity-card");
   const heading = node("div", "report-head");
   heading.append(node("strong", "", ACTION_LABELS[event.action] || event.action), node("span", "report-meta", dateLabel(event.created_at)));
   const target = node("p", "report-meta", (event.entity_type || "—") + " · " + (event.entity_id || "—"));
   const actor = node("p", "report-ids", "المشرف: " + (event.user_id || "—"));
   card.append(heading, target, actor);
   if (event.details?.reason) card.append(node("p", "report-meta", "السبب: " + event.details.reason));
   if (event.details?.new_status) card.append(node("p", "report-meta", "الحالة الجديدة: " + (STATUS_LABELS[event.details.new_status] || event.details.new_status)));
   list.append(card);
  }
 } catch (error) {
  list.replaceChildren(node("p", "error-state", error.message));
  message(error.message, true);
 }
}
async function loadAdmins() {
 const list = $("#admin-list");
 if (!list) return;
 list.replaceChildren(node("p", "muted", "جارٍ تحميل الحسابات…"));
 try {
  const { admins = [] } = await api("list_admins");
  list.replaceChildren();
  if (!admins.length) { list.append(node("p", "muted", "لا توجد حسابات Admin حاليًا.")); return; }
  for (const admin of admins) {
   const row = node("div", "admin-row");
   const info = node("div", "admin-info");
   info.append(node("strong", "", admin.email), node("span", "", admin.enabled ? "مفعّل" : "معطّل"));
   const remove = node("button", "danger", "حذف");
   remove.type = "button";
   remove.addEventListener("click", async () => {
    if (!window.confirm("تأكيد حذف حساب الأدمن " + admin.email + "؟ لا يمكن التراجع عن الحذف.")) return;
    remove.disabled = true;
    try { await api("delete_admin", { user_id: admin.user_id }); message("تم حذف حساب الأدمن."); await loadAdmins(); await loadActivity(); }
    catch (error) { message(error.message, true); remove.disabled = false; }
   });
   row.append(info, remove);
   list.append(row);
  }
 } catch (error) { list.replaceChildren(node("p", "error-state", error.message)); }
}
async function restoreSession() {
 if (!localStorage.getItem(SESSION_KEY)) return;
 const restore = async () => {
  const saved = localStorage.getItem(SESSION_KEY);
  if (!saved) return;
  const parsed = JSON.parse(saved);
  if (!parsed.refresh_token) { const error = new Error("بيانات الجلسة غير مكتملة."); error.status = 401; throw error; }
  const result = await api("refresh_session", { refresh_token: parsed.refresh_token });
  if (!result.session?.access_token || !result.session?.refresh_token) throw new Error("استجابة استعادة الجلسة غير مكتملة.");
  show(result.session);
  message("");
 };
 try {
  if (navigator.locks?.request) await navigator.locks.request("nova-admin-session-refresh", restore);
  else await restore();
 } catch (error) {
  if (error.status === 401 || error.status === 403) {
   clearSession();
   $("#app-panel").hidden = true;
   $("#login-panel").hidden = false;
   message("انتهت صلاحية الجلسة أو لم تعد صلاحية الحساب مفعّلة. سجّل الدخول مجددًا.", true);
  } else {
   $("#app-panel").hidden = true;
   $("#login-panel").hidden = false;
   message("تعذر التحقق من الجلسة بسبب مشكلة اتصال. لم نحذف جلسة الدخول؛ حدّث الصفحة للمحاولة مجددًا.", true);
  }
 }
}
document.querySelectorAll("[data-view]").forEach(button => button.addEventListener("click", () => switchView(button.dataset.view)));
$("#login-form").addEventListener("submit", async event => {
 event.preventDefault();
 const form = new FormData(event.currentTarget);
 try { show((await api("login", { email: form.get("email"), password: form.get("password") })).session); message(""); }
 catch (error) { message(error.message, true); }
});
$("#create-admin-form").addEventListener("submit", async event => {
 event.preventDefault();
 const form = event.currentTarget;
 if (!accessToken || $("#owner-panel").hidden) return;
 const values = new FormData(form);
 try { await api("create_admin", { email: values.get("email"), password: values.get("password") }); form.reset(); message("تم إنشاء حساب Admin."); await loadAdmins(); await loadActivity(); }
 catch (error) { message(error.message, true); }
});
$("#refresh-admins").addEventListener("click", loadAdmins);
$("#refresh-reports").addEventListener("click", loadReports);
$("#refresh-activity").addEventListener("click", loadActivity);
$("#player-search-form").addEventListener("submit", event => {
 event.preventDefault();
 const query = new FormData(event.currentTarget).get("query");
 loadPlayers(String(query || "").trim());
});
$("#logout-button").addEventListener("click", () => {
 clearSession();
 $("#app-panel").hidden = true;
 $("#login-panel").hidden = false;
 document.querySelectorAll(".owner-nav").forEach(item => item.hidden = true);
 message("تم تسجيل الخروج.");
});
restoreSession();
