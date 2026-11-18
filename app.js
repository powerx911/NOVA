(()=>{"use strict";
const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
const fmt=n=>new Intl.NumberFormat("en-US").format(n);
const KEY="nova-competitive-preview-v1";
const base={credits:24850,energy:76,influence:1240,materials:340,battles:12,upgrades:0};
let state={...base,...read()};let toastTimer;
function read(){try{return JSON.parse(localStorage.getItem(KEY))||{}}catch{return{}}}
function save(){try{localStorage.setItem(KEY,JSON.stringify(state))}catch{notify("تعذر حفظ بيانات العرض على هذا الجهاز.")}}
function notify(msg){const el=$("#toast");el.textContent=msg;el.classList.add("show");clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove("show"),2400)}
function feedback(){if(navigator.vibrate)navigator.vibrate(8)}
function dialog(title,message,mark="✦",kicker="NOVA SYSTEM"){$("#dialog-title").textContent=title;$("#dialog-message").textContent=message;$("#dialog-mark").textContent=mark;$("#dialog-kicker").textContent=kicker;$("#action-dialog").showModal()}
function update(){ $("#credits").textContent=fmt(state.credits);$("#energy").textContent=state.energy;$("#influence").textContent=fmt(state.influence);$("#battle-count").textContent=state.battles;$("#alloy-count").textContent=fmt(state.materials);$("#power").textContent=fmt(2860+state.upgrades*85);$("#income").textContent="+"+fmt(1240+state.upgrades*90);$("#asset-value").textContent=fmt(186420+state.upgrades*4200)+" ◈";$("#net-worth").textContent=fmt(186420+state.upgrades*4200)}
function navigate(name){const target=$("#screen-"+name);if(!target)return;$$(".screen").forEach(x=>x.classList.toggle("active",x===target));$$(".nav-item").forEach(x=>x.classList.toggle("active",x.dataset.screen===name));window.scrollTo({top:0,behavior:"smooth"});feedback()}
$$(".nav-item").forEach(b=>b.addEventListener("click",()=>navigate(b.dataset.screen)));
$$("[data-go]").forEach(b=>b.addEventListener("click",()=>navigate(b.dataset.go)));
$("#open-profile").addEventListener("click",()=>navigate("profile"));
$("#notifications").addEventListener("click",()=>dialog("لا توجد إشعارات جديدة","ستظهر هنا تنبيهات المنافسات والصفقات والأنشطة المهمة عند ربط خدمات اللعب الجماعي.","♧","الإشعارات"));
$("#run-simulation").addEventListener("click",()=>{if(state.energy<10)return notify("تحتاج إلى 10 طاقة.");state.energy-=10;state.battles++;state.credits+=320;state.influence+=12;save();update();feedback();dialog("اكتملت المحاكاة التدريبية","نتيجة محلية للعرض فقط: كفاءة التشكيلة 87%. حصلت على 320 رصيداً و12 نفوذاً. لم يتم الاتصال بلاعب حقيقي.","⚡","تقرير التدريب")});
$("#buy-materials").addEventListener("click",()=>{if(state.credits<500)return notify("رصيدك لا يكفي.");state.credits-=500;state.materials+=50;save();update();feedback();notify("أضيفت 50 سبيكة إلى مخزون العرض.")});
$("#upgrade-assets").addEventListener("click",()=>{if(state.credits<1800)return notify("تحتاج إلى 1,800 رصيد للتطوير.");state.credits-=1800;state.upgrades++;save();update();feedback();notify("تم تطوير الأصول في بيانات العرض.")});
$$(".row-action").forEach(b=>b.addEventListener("click",()=>dialog(b.dataset.asset,"يمكن تطوير هذا الأصل أو متابعة إنتاجه. خيارات التطوير الكاملة ستُفعّل ضمن نظام الأصول.","↗","تفاصيل الأصل")));
$$(".inventory-item").forEach(b=>b.addEventListener("click",()=>dialog(b.dataset.item,"عنصر ضمن مخزون العرض. ستظهر هنا خصائص العنصر واستخداماته وخيارات البيع أو التطوير.","⬡","تفاصيل المخزون")));
$$(".join-challenge").forEach(b=>b.addEventListener("click",()=>dialog(b.dataset.name,"هذه بطاقة تحدٍ تجريبية. التسجيل والمنافسة الفعلية سيُفعّلان بعد ربط نظام الجلسات والنتائج بالخادم.","⚡","تفاصيل التحدي")));
$("#request-alliance").addEventListener("click",()=>dialog("طلب الانضمام","واجهة طلب الانضمام تجريبية حالياً؛ لم يُرسل أي طلب إلى خادم أو منظمة حقيقية.","✦","المنظمات"));
$("#alliance-info").addEventListener("click",()=>dialog("المنظمات","ستدعم المنظمات العضويات والرتب والصلاحيات والمشاريع الجماعية والمحادثات الخاصة.","♧","المجتمع"));
$("#edit-profile").addEventListener("click",()=>dialog("تعديل الملف","إعدادات الهوية والصورة والخصوصية قيد التخطيط.","✎","الملف الشخصي"));
$("#settings").addEventListener("click",()=>dialog("الإعدادات","ستتضمن إعدادات الحساب واللغة والصوت والاهتزاز والإشعارات والخصوصية.","⚙","الإعدادات"));
$("#help").addEventListener("click",()=>dialog("المساعدة والدعم","مركز المساعدة والإبلاغ عن المشكلات سيُضاف قبل الإطلاق العام.","◉","الدعم"));
$("#reset-demo").addEventListener("click",()=>{state={...base};save();update();notify("أُعيد ضبط بيانات العرض.")});
$("#dialog-close").addEventListener("click",()=>$("#action-dialog").close());
document.addEventListener("click",e=>{const b=e.target.closest("button");if(b&&!b.disabled&&b.id!=="dialog-close")feedback()});
update();
})();