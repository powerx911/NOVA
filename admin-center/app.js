const API_URL = "https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/admin-center";
let accessToken = "";
const SESSION_KEY = "nova_admin_session";
const $ = (selector) => document.querySelector(selector);
let playerSearchTimer = null;
let playerSearchRequest = 0;
const STATUS_LABELS = { open: "مفتوح", new: "جديد", reviewing: "قيد المراجعة", closed: "مغلق", resolved: "تمت المعالجة", dismissed: "مستبعد" };
const REASON_LABELS = { harassment: "مضايقة", spam: "رسائل مزعجة", inappropriate: "محتوى غير مناسب", impersonation: "انتحال شخصية", other: "سبب آخر" };
const ACTION_LABELS = {
 admin_account_created: "إنشاء حساب مشرف",
 admin_account_deleted: "حذف حساب مشرف",
 admin_report_status_changed: "تحديث حالة بلاغ لاعب",
 admin_report_notification_sent: "إرسال إشعار لصاحب البلاغ",
 admin_ticket_claimed: "استلام تذكرة دعم",
 admin_ticket_message_sent: "الرد على تذكرة دعم",
 admin_ticket_closed: "إغلاق تذكرة دعم"
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
 const titles = { overview: "نظرة عامة", reports: "بلاغات اللاعبين", tickets: "التذاكر", players: "إدارة اللاعبين", activity: "سجل الإجراءات", admins: "حسابات المشرفين" };
 $("#page-title").textContent = titles[name] || "مركز الإدارة";
 if (name === "overview") loadOverview();
 if (name === "reports") loadReports();
 if (name === "tickets") loadTickets();
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
 list.replaceChildren(node("p", "muted", "جارٍ تحميل البلاغات والاقتراحات…"));
 try {
  const { reports = [] } = await api("list_player_reports");
  list.replaceChildren();
  if (!reports.length) { list.append(node("p", "empty-state", "لا توجد بلاغات أو اقتراحات حاليًا.")); return; }
  for (const report of reports) {
   const isFeedback = report.source === "player_feedback";
   const isSuggestion = isFeedback && report.kind === "suggestion";
   const card = node("article", "report-card");
   const head = node("div", "report-head");
   const titleText = isFeedback ? (isSuggestion ? "اقتراح من " : "بلاغ من ") + (report.reporter_name || "لاعب غير معروف") : "بلاغ من " + (report.reporter_name || "لاعب غير معروف") + " على " + (report.target_name || "لاعب غير معروف");
   head.append(node("strong", "", titleText), node("span", "status-badge status-" + report.status, STATUS_LABELS[report.status] || report.status));
   const meta = node("p", "report-meta", (isFeedback ? (isSuggestion ? "اقتراح لاعب" : "بلاغ لاعب") : (REASON_LABELS[report.reason] || report.reason)) + " · " + dateLabel(report.created_at));
   const ids = node("p", "report-ids", "صاحب الرسالة: " + report.reporter_uid + (isFeedback ? "" : " · اللاعب المبلّغ عنه: " + report.target_uid));
   const controls = node("div", "report-controls");
   const statuses = ["open", "reviewing", "closed"];
   const status = node("select", "status-select");
   for (const value of statuses) { const option = node("option", "", STATUS_LABELS[value]); option.value = value; status.append(option); }
   status.value = report.status;
   const reason = node("input", "reason-input"); reason.type = "text"; reason.maxLength = 500;
   reason.placeholder = "سبب تحديث الحالة (8 أحرف على الأقل)";
   const save = node("button", "small-button", "حفظ الإجراء"); save.type = "button";
   save.addEventListener("click", async () => {
    save.disabled = true;
    try {
     await api("update_player_report", { report_id: report.id, source: isFeedback ? "player_feedback" : "player_report", status: status.value, reason: reason.value });
     message("تم تحديث الرسالة وتسجيل الإجراء."); await loadReports(); await loadOverview();
    } catch (error) { message(error.message, true); save.disabled = false; }
   });
   controls.append(status, reason, save);
   const content = node("p", "report-message", report.message || report.reason || "لم يكتب اللاعب سببًا للبلاغ.");
   content.style.whiteSpace = "pre-wrap"; content.style.overflowWrap = "anywhere";
   card.append(head, meta, content, ids);
   for (const url of report.attachments || []) {
    const image = node("img", "report-attachment"); image.src = url; image.alt = "مرفق من اللاعب";
    image.addEventListener("click", () => window.open(url, "_blank", "noopener")); card.append(image);
   }
   const notify = node("button", "small-button secondary", "إرسال إشعار للاعب");
   notify.addEventListener("click", async () => {
    const text = window.prompt("اكتب رسالة للاعب");
    if (!text || text.trim().length < 3) return;
    try { await api("send_player_report_notification", { report_id: report.id, source: isFeedback ? "player_feedback" : "player_report", message: text.trim() }); message("تم إرسال الإشعار للاعب."); }
    catch (error) { message(error.message, true); }
   });
   controls.append(notify);
   card.append(controls);
   list.append(card);
  }
 } catch (error) { list.replaceChildren(node("p", "error-state", error.message)); message(error.message, true); }
}

async function loadTickets() {
 const list = $("#tickets-list");
 list.replaceChildren(node("p", "muted", "جارٍ تحميل التذاكر…"));
 try {
  const result = await api("list_support_tickets");
  const tickets = result.tickets || [];
  list.replaceChildren();
  if (!tickets.length) { list.append(node("p", "empty-state", "لا توجد تذاكر حالياً.")); return; }
  for (const ticket of tickets) {
   const card = node("article", "ticket-card");
   card.append(node("strong", "", ticket.subject + " · " + (ticket.player_name || "لاعب غير معروف")));
   card.append(node("p", "report-ids", "اللاعب: " + ticket.user_id + " · " + dateLabel(ticket.created_at)));
   for (const item of ticket.messages || []) {
    const bubble = node("div", "ticket-message");
    bubble.append(node("strong", "", item.sender_type === "admin" ? "الإدارة" : "اللاعب"));
    bubble.append(node("p", "", item.message));
    card.append(bubble);
    for (const url of item.attachments || []) { const img = node("img", "report-attachment"); img.src = url; img.alt = "مرفق"; card.append(img); }
   }
   if (ticket.status === "open") {
    const claim = node("button", "small-button", "استلام التذكرة");
    claim.addEventListener("click", async () => { try { await api("claim_support_ticket", {ticket_id:ticket.id}); message("تم استلام التذكرة."); await loadTickets(); } catch(error) { message(error.message,true); } });
    card.append(claim);
   }
   if (ticket.status !== "closed") {
    const input = node("textarea", "reason-input"); input.placeholder = "اكتب ردك للاعب";
    const send = node("button", "small-button", "إرسال الرد");
    send.addEventListener("click", async () => { if(!input.value.trim()) return; try { await api("send_support_ticket_message",{ticket_id:ticket.id,message:input.value.trim()}); message("تم إرسال الرد."); await loadTickets(); } catch(error) { message(error.message,true); } });
    const close = node("button", "small-button danger", "إغلاق التذكرة");
    close.addEventListener("click", async () => { try { await api("close_support_ticket",{ticket_id:ticket.id}); message("تم إغلاق التذكرة."); await loadTickets(); } catch(error) { message(error.message,true); } });
    card.append(input,send,close);
   }
   list.append(card);
  }
 } catch(error) { list.replaceChildren(node("p","error-state",error.message)); }
}

async function loadPlayers(query) {
 const requestId = ++playerSearchRequest;
 const list = $("#players-list");
 list.replaceChildren(node("p", "muted", "جارٍ البحث…"));
 try {
  const { players = [] } = await api("search_players", { query });
  if (requestId !== playerSearchRequest) return;
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
  if (requestId !== playerSearchRequest) return;
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
$("#refresh-tickets").addEventListener("click", loadTickets);
$("#refresh-activity").addEventListener("click", loadActivity);
const playerSearchForm = $("#player-search-form");
const playerSearchInput = playerSearchForm.elements.query;
playerSearchInput.addEventListener("input", () => {
 const query = playerSearchInput.value.trim();
 clearTimeout(playerSearchTimer);
 if (!query) {
  playerSearchRequest++;
  $("#players-list").replaceChildren(node("p", "muted", "اكتب حرفًا واحدًا على الأقل لعرض الحسابات المطابقة."));
  return;
 }
 playerSearchTimer = setTimeout(() => loadPlayers(query), 140);
});
playerSearchForm.addEventListener("submit", event => {
 event.preventDefault();
 clearTimeout(playerSearchTimer);
 const query = playerSearchInput.value.trim();
 if (query) loadPlayers(query);
});
$("#logout-button").addEventListener("click", () => {
 clearSession();
 $("#app-panel").hidden = true;
 $("#login-panel").hidden = false;
 document.querySelectorAll(".owner-nav").forEach(item => item.hidden = true);
 message("تم تسجيل الخروج.");
});
restoreSession();
