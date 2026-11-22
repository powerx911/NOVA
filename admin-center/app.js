const API_URL = "https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/admin-center";
let accessToken = "";
const SESSION_KEY = "nova_admin_session";
const $ = (selector) => document.querySelector(selector);
let playerSearchTimer = null;
let playerSearchRequest = 0;
let ticketSnapshot = "";
let ticketLoadRequest = 0;
let selectedAdminTicketId = null;
const STATUS_LABELS = { open: "مفتوح", new: "جديد", reviewing: "قيد المراجعة", closed: "مغلق", resolved: "تمت المعالجة", dismissed: "مستبعد" };
const REASON_LABELS = { harassment: "مضايقة", spam: "رسائل مزعجة", inappropriate: "محتوى غير مناسب", impersonation: "انتحال شخصية", other: "سبب آخر" };
const ACTION_LABELS = {
 admin_account_created: "إنشاء حساب مشرف",
 admin_account_deleted: "حذف حساب مشرف",
 admin_report_status_changed: "تحديث حالة بلاغ لاعب",
 admin_report_notification_sent: "إرسال إشعار لصاحب البلاغ",
 admin_ticket_claimed: "استلام تذكرة دعم",
 admin_ticket_message_sent: "الرد على تذكرة دعم",
 admin_ticket_closed: "إغلاق تذكرة دعم",
 admin_ticket_deleted: "حذف تذكرة دعم",
 admin_report_deleted: "حذف بلاغ لاعب",
 admin_account_renamed: "تغيير اسم مشرف",
 admin_player_wallet_adjusted: "تعديل رصيد لاعب",
 admin_player_banned: "تبنيد حساب لاعب",
 admin_player_message_sent: "إرسال رسالة من إدارة اللعبة"
};
function saveSession(session) {
 accessToken = session.access_token;
 localStorage.setItem(SESSION_KEY, JSON.stringify({ refresh_token: session.refresh_token, email: session.email, role: session.role, display_name: session.display_name }));
}
function clearSession() { accessToken = ""; localStorage.removeItem(SESSION_KEY); }
function isOwnerSession() { try { return JSON.parse(localStorage.getItem(SESSION_KEY) || "{}").role === "owner"; } catch { return false; } }
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
  INVALID_REPORT_UPDATE: "اختر حالة صحيحة للبلاغ.",
  REPORT_NOT_FOUND: "البلاغ غير موجود أو تم حذفه.",
  REPORT_UPDATE_FAILED: "تعذر تحديث حالة البلاغ.",
  REPORT_DELETE_FAILED: "تعذر حذف البلاغ.",
  TICKET_DELETE_FAILED: "تعذر حذف التذكرة.",
  PLAYER_SEARCH_TOO_SHORT: "اكتب حرفين على الأقل للبحث.",
  PLAYER_SEARCH_FAILED: "تعذر البحث عن اللاعبين.",
  ADMIN_ACTIVITY_FAILED: "تعذر تحميل سجل الإجراءات.",
  INVALID_ADMIN_WALLET_ADJUSTMENT: "تحقق من المبلغ ونوع العملية.",
  PLAYER_WALLET_NOT_FOUND: "لم يتم العثور على محفظة اللاعب.",
  INSUFFICIENT_PLAYER_BALANCE: "رصيد اللاعب أقل من المبلغ المطلوب خصمه.",
  INVALID_PLAYER_BAN: "تحقق من مدة الحظر والسبب.",
  PLAYER_NOT_FOUND: "لم يتم العثور على اللاعب.",
  PLAYER_MESSAGE_FAILED: "تعذر إرسال رسالة إدارة اللعبة.",
  INVALID_PLAYER_MESSAGE: "اكتب رسالة صحيحة لا تتجاوز 1000 حرف.",
  WALLET_ADJUSTMENT_FAILED: "تعذر تعديل رصيد اللاعب.",
  PLAYER_BAN_FAILED: "تعذر تبنيد حساب اللاعب.",
  PLAYER_UNBAN_FAILED: "تعذر فك الحظر عن حساب اللاعب.",
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
 $("#session-label").textContent = (session.display_name || (session.role === "owner" ? "MJNON" : "مشرف")) + " · " + (session.role === "owner" ? "Owner" : "Admin");
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
   const meta = node("p", "report-meta", (isFeedback ? (isSuggestion ? "اقتراح لاعب" : "بلاغ لاعب") : "بلاغ على لاعب") + " · " + dateLabel(report.created_at));
   const ids = node("p", "report-ids", "صاحب البلاغ: " + (report.reporter_name || "لاعب غير معروف") + (isFeedback ? "" : " · المبلّغ عنه: " + (report.target_name || "لاعب غير معروف")));
   const controls = node("div", "report-controls");
   const statuses = ["open", "reviewing", "closed"];
   const status = node("select", "status-select");
   for (const value of statuses) { const option = node("option", "", STATUS_LABELS[value]); option.value = value; status.append(option); }
   status.value = report.status;
   const reason = node("input", "reason-input"); reason.type = "text"; reason.maxLength = 500;
   reason.placeholder = "ملاحظة إدارية (اختياري)";
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
   if (isOwnerSession()) {
    const remove = node("button", "small-button danger", "حذف البلاغ");
    remove.addEventListener("click", async () => {
     if (!window.confirm("هل أنت متأكد من حذف هذا البلاغ نهائيًا؟")) return;
     remove.disabled = true;
     try { await api("delete_player_report", { report_id: report.id, source: isFeedback ? "player_feedback" : "player_report" }); message("تم حذف البلاغ."); await loadReports(); await loadOverview(); }
     catch (error) { message(error.message, true); remove.disabled = false; }
    });
    controls.append(remove);
   }
   card.append(controls);
   list.append(card);
  }
 } catch (error) { list.replaceChildren(node("p", "error-state", error.message)); message(error.message, true); }
}

function closeTicketDetail() {
 document.querySelector(".ticket-detail-overlay")?.remove();
 selectedAdminTicketId = null;
}
function ticketStatusLabel(status) {
 return status === "claimed" ? "تم استلامها" : status === "closed" ? "مغلقة" : "مفتوحة";
}
function renderTicketDetail(ticket) {
 let overlay = document.querySelector(".ticket-detail-overlay");
 if (!overlay) {
  overlay = node("div", "ticket-detail-overlay");
  overlay.setAttribute("role", "dialog");
  overlay.setAttribute("aria-modal", "true");
  overlay.setAttribute("aria-label", "تفاصيل تذكرة الدعم");
  document.body.append(overlay);
 }
 overlay.replaceChildren();
 const panel = node("section", "ticket-detail-panel");
 const header = node("header", "ticket-detail-header");
 const back = node("button", "secondary ticket-back", "رجوع إلى التذاكر");
 back.type = "button"; back.addEventListener("click", closeTicketDetail);
 const heading = node("div", "ticket-detail-heading");
 heading.append(node("h2", "", ticket.subject), node("p", "report-meta", (ticket.player_name || "لاعب غير معروف") + " · " + dateLabel(ticket.created_at)));
 const status = node("span", "status-badge status-" + (ticket.status === "closed" ? "closed" : ticket.status === "claimed" ? "reviewing" : "open"), ticketStatusLabel(ticket.status));
 header.append(back, heading, status);
 const messages = node("div", "ticket-detail-messages");
 for (const item of ticket.messages || []) {
  const bubble = node("article", "ticket-message");
  const top = node("div", "ticket-detail-message-head");
  top.append(node("strong", "", item.sender_type === "admin" ? "الإدارة" : "اللاعب"), node("small", "", dateLabel(item.created_at)));
  bubble.append(top, node("p", "", item.message));
  for (const url of item.attachments || []) {
   const img = node("img", "report-attachment"); img.src = url; img.alt = "مرفق";
   img.addEventListener("click", () => window.open(url, "_blank", "noopener"));
   bubble.append(img);
  }
  messages.append(bubble);
 }
 if (!(ticket.messages || []).length) messages.append(node("p", "empty-state", "لا توجد رسائل في هذه التذكرة."));
 panel.append(header, messages);
 const controls = node("footer", "ticket-detail-controls");
 if (ticket.status === "open") {
  const claim = node("button", "small-button", "استلام التذكرة");
  claim.addEventListener("click", async () => {
   claim.disabled = true;
   try { await api("claim_support_ticket", {ticket_id:ticket.id}); message("تم استلام التذكرة وإشعار اللاعب."); ticketSnapshot = ""; await loadTickets(); }
   catch(error) { message(error.message,true); claim.disabled = false; }
  });
  controls.append(claim);
 }
 if (ticket.status === "claimed") {
  const input = node("textarea", "reason-input"); input.placeholder = "اكتب ردك للاعب";
  const send = node("button", "small-button", "إرسال الرد");
  send.addEventListener("click", async () => {
   if(!input.value.trim()) return;
   send.disabled = true;
   try { await api("send_support_ticket_message",{ticket_id:ticket.id,message:input.value.trim()}); message("تم إرسال الرد وإشعار اللاعب."); ticketSnapshot = ""; await loadTickets(); }
   catch(error) { message(error.message,true); send.disabled = false; }
  });
  const close = node("button", "small-button danger", "إغلاق التذكرة");
  close.addEventListener("click", async () => {
   if (!window.confirm("سيتم إغلاق التذكرة وإشعار اللاعب. هل تريد المتابعة؟")) return;
   close.disabled = true;
   try { await api("close_support_ticket",{ticket_id:ticket.id}); message("تم إغلاق التذكرة وإشعار اللاعب."); ticketSnapshot = ""; await loadTickets(); }
   catch(error) { message(error.message,true); close.disabled = false; }
  });
  controls.append(input,send,close);
 }
 if (ticket.status === "closed") controls.append(node("p", "muted", "هذه التذكرة مغلقة."));
 if (isOwnerSession()) {
  const remove = node("button", "small-button danger", "حذف التذكرة نهائيًا");
  remove.addEventListener("click", async () => {
   if (!window.confirm("سيتم حذف التذكرة وجميع رسائلها نهائيًا. هل تريد المتابعة؟")) return;
   remove.disabled = true;
   try { await api("delete_support_ticket", {ticket_id:ticket.id}); message("تم حذف التذكرة ورسائلها."); ticketSnapshot = ""; closeTicketDetail(); await loadTickets(); await loadOverview(); }
   catch(error) { message(error.message,true); remove.disabled = false; }
  });
  controls.append(remove);
 }
 if (controls.childElementCount) panel.append(controls);
 overlay.append(panel);
}
async function loadTickets() {
 const requestId = ++ticketLoadRequest;
 const list = $("#tickets-list");
 if (!list.childElementCount) list.replaceChildren(node("p", "muted", "جارٍ تحميل التذاكر…"));
 try {
  const result = await api("list_support_tickets");
  if (requestId !== ticketLoadRequest) return;
  const tickets = result.tickets || [];
  const snapshot = JSON.stringify(tickets.map(ticket => [ticket.id, ticket.status, ticket.updated_at, (ticket.messages || []).at(-1)?.id]));
  if (snapshot !== ticketSnapshot || !list.childElementCount) {
   ticketSnapshot = snapshot;
   list.replaceChildren();
   if (!tickets.length) list.append(node("p", "empty-state", "لا توجد تذاكر حالياً."));
   for (const ticket of tickets) {
    const card = node("button", "ticket-summary", "");
    card.type = "button";
    const main = node("div", "ticket-summary-main");
    const title = node("strong", "", ticket.subject);
    const meta = node("p", "report-meta", (ticket.player_name || "لاعب غير معروف") + " · " + dateLabel(ticket.created_at));
    const last = (ticket.messages || []).at(-1);
    const preview = node("p", "ticket-summary-preview", last ? (last.sender_type === "admin" ? "الإدارة: " : "اللاعب: ") + last.message : "لا توجد رسائل");
    main.append(title,meta,preview);
    const side = node("div", "ticket-summary-side");
    side.append(node("span", "status-badge status-" + (ticket.status === "closed" ? "closed" : ticket.status === "claimed" ? "reviewing" : "open"), ticketStatusLabel(ticket.status)));
    side.append(node("span", "ticket-summary-count", (ticket.messages || []).length + " رسائل"));
    card.append(main,side);
    card.addEventListener("click", () => { selectedAdminTicketId = ticket.id; renderTicketDetail(ticket); });
    list.append(card);
   }
  }
  if (selectedAdminTicketId) {
   const selected = tickets.find(ticket => ticket.id === selectedAdminTicketId);
   if (selected) renderTicketDetail(selected);
   else closeTicketDetail();
  }
 } catch(error) {
  if (requestId !== ticketLoadRequest) return;
  list.replaceChildren(node("p","error-state",error.message));
  message(error.message, true);
 }
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
   if (player.is_banned) {
    card.append(node("p", "owner-ban-status", (player.ban_expires_at ? "الحساب محظور حتى " + dateLabel(player.ban_expires_at) : "الحساب محظور بشكل دائم") + " · " + (player.ban_reason || "")));
   }
   if (isOwnerSession()) {
    const controls = node("div", "owner-player-controls");
    controls.append(node("strong", "owner-controls-title", "إدارة رصيد اللاعب"));
    const amount = node("input", "reason-input"); amount.type = "number"; amount.min = "1"; amount.step = "1"; amount.placeholder = "المبلغ";
    const walletReason = node("input", "reason-input"); walletReason.maxLength = 500; walletReason.placeholder = "سبب تعديل الرصيد (اختياري)";
    const walletRow = node("div", "owner-control-row");
    const add = node("button", "small-button", "إضافة أموال");
    const remove = node("button", "small-button danger", "إزالة أموال");
    const adjust = async (operation, button) => {
     const value = Number(amount.value);
     if (!Number.isSafeInteger(value) || value < 1) { message("أدخل مبلغًا صحيحًا أكبر من صفر.", true); return; }
     button.disabled = true;
     try { const result = await api("adjust_player_wallet", { user_id: player.user_id, amount: value, operation, reason: walletReason.value.trim() }); message("تم تعديل الرصيد. الرصيد الجديد: " + Number(result.balance).toLocaleString("ar")); await loadPlayers(query); await loadActivity(); }
     catch (error) { message(error.message, true); button.disabled = false; }
    };
    add.addEventListener("click", () => void adjust("add", add));
    remove.addEventListener("click", () => void adjust("remove", remove));
    walletRow.append(amount, walletReason, add, remove);
    controls.append(walletRow);
    controls.append(node("strong", "owner-controls-title", "تبنيد الحساب"));
    const permanentLabel = node("label", "owner-control-row");
    const permanent = node("input", ""); permanent.type = "checkbox";
    const permanentText = node("span", "", "حظر دائم");
    permanentLabel.append(permanent, permanentText);
    const duration = node("input", "reason-input"); duration.type = "number"; duration.min = "1"; duration.step = "1"; duration.placeholder = "مدة الحظر بالدقائق";
    permanent.addEventListener("change", () => { duration.hidden = permanent.checked; duration.required = !permanent.checked; if (permanent.checked) duration.value = ""; });
    const banReason = node("textarea", "reason-input"); banReason.maxLength = 500; banReason.placeholder = "سبب التبنيد (إلزامي)";
    const banButton = node("button", "small-button danger", player.is_banned ? "تحديث الحظر" : "تبنيد الحساب");
    banButton.addEventListener("click", async () => {
     const durationMinutes = Number(duration.value);
     if (!permanent.checked && (!Number.isSafeInteger(durationMinutes) || durationMinutes < 1 || durationMinutes > 525600)) { message("أدخل مدة صحيحة بالدقائق (من 1 إلى 525600)، أو اختر الحظر الدائم.", true); return; }
     if (banReason.value.trim().length < 3) { message("اكتب سببًا واضحًا للتبنيد (3 أحرف على الأقل).", true); return; }
     if (!window.confirm("تأكيد تبنيد اللاعب " + player.username + (permanent.checked ? " بشكل دائم؟" : " لمدة " + durationMinutes + " دقيقة؟"))) return;
     banButton.disabled = true;
     try { await api("ban_player_account", { user_id: player.user_id, duration_minutes: permanent.checked ? null : durationMinutes, permanent: permanent.checked, reason: banReason.value.trim() }); message("تم تبنيد الحساب."); await loadPlayers(query); await loadActivity(); }
     catch (error) { message(error.message, true); banButton.disabled = false; }
    });
    controls.append(permanentLabel, duration, banReason, banButton);
    if (player.is_banned) {
     const unbanButton = node("button", "small-button secondary", "فك الحظر");
     unbanButton.addEventListener("click", async () => {
      if (!window.confirm("تأكيد فك الحظر عن اللاعب " + player.username + "؟")) return;
      unbanButton.disabled = true;
      try { await api("unban_player_account", { user_id: player.user_id }); message("تم فك الحظر عن الحساب."); await loadPlayers(query); await loadActivity(); }
      catch (error) { message(error.message, true); unbanButton.disabled = false; }
     });
     controls.append(unbanButton);
    }
    controls.append(node("strong", "owner-controls-title", "رسالة إدارة اللعبة"));
    const messageInput = node("textarea", "reason-input"); messageInput.maxLength = 1000; messageInput.placeholder = "اكتب رسالة تظهر للاعب في صفحة التواصل";
    const sendMessage = node("button", "small-button", "إرسال رسالة للاعب");
    sendMessage.addEventListener("click", async () => {
     if (!messageInput.value.trim()) { message("اكتب الرسالة أولاً.", true); return; }
     sendMessage.disabled = true;
     try { await api("send_player_admin_message", { user_id: player.user_id, message: messageInput.value.trim() }); message("تم إرسال الرسالة إلى التواصل."); messageInput.value = ""; sendMessage.disabled = false; await loadActivity(); }
     catch (error) { message(error.message, true); sendMessage.disabled = false; }
    });
    controls.append(messageInput, sendMessage);
    card.append(controls);
   }
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
   const entityLabels = { player_feedback: "بلاغ أو اقتراح من داخل اللعبة", player_report: "بلاغ لاعب على لاعب", support_ticket: "تذكرة دعم", admin_account: "حساب مشرف" };
   const target = node("p", "report-meta", entityLabels[event.entity_type] || "إجراء إداري");
   const actor = node("p", "report-ids", "المشرف: " + (event.actor_name || "مشرف"));
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
   info.append(node("strong", "", admin.display_name || "مشرف"), node("span", "", admin.email + " · " + (admin.enabled ? "مفعّل" : "معطّل")));
   const edit = node("div", "admin-edit");
   const nameInput = node("input", "reason-input");
   nameInput.type = "text"; nameInput.maxLength = 40; nameInput.minLength = 2; nameInput.value = admin.display_name || "";
   nameInput.setAttribute("aria-label", "الاسم الظاهر للاعبين");
   const saveName = node("button", "small-button", "حفظ الاسم");
   saveName.type = "button";
   saveName.addEventListener("click", async () => {
    if (nameInput.value.trim().length < 2) { message("الاسم يجب أن يكون حرفين على الأقل.", true); return; }
    saveName.disabled = true;
    try { await api("update_admin_display_name", { user_id: admin.user_id, display_name: nameInput.value.trim() }); message("تم تحديث اسم المشرف."); await loadAdmins(); }
    catch (error) { message(error.message, true); saveName.disabled = false; }
   });
   edit.append(nameInput, saveName);
   const remove = node("button", "danger", "حذف");
   remove.type = "button";
   remove.addEventListener("click", async () => {
    if (!window.confirm("تأكيد حذف حساب الأدمن " + admin.email + "؟ لا يمكن التراجع عن الحذف.")) return;
    remove.disabled = true;
    try { await api("delete_admin", { user_id: admin.user_id }); message("تم حذف حساب الأدمن."); await loadAdmins(); await loadActivity(); }
    catch (error) { message(error.message, true); remove.disabled = false; }
   });
   row.append(info, edit, remove);
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
 try { await api("create_admin", { email: values.get("email"), password: values.get("password"), display_name: values.get("display_name") }); form.reset(); message("تم إنشاء حساب Admin."); await loadAdmins(); await loadActivity(); }
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
window.setInterval(() => {
 const view = $("#view-tickets");
 const list = $("#tickets-list");
 if (view?.classList.contains("active") && list && !list.contains(document.activeElement)) void loadTickets();
}, 5000);
restoreSession();
