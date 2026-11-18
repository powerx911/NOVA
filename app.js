(() => {
"use strict";
const $ = (s, r=document) => r.querySelector(s);
const $$ = (s, r=document) => [...r.querySelectorAll(s)];
const fmt = n => new Intl.NumberFormat("en-US").format(n);
const KEY = "nova-dominion-preview-v1";
const initial = {cash:12450,energy:86,materials:340,influence:125,battles:0,businesses:[{name:"مركز التوزيع",type:"لوجستيات",icon:"▤",income:180},{name:"ورشة أطلس",type:"تصنيع",icon:"⚒",income:140},{name:"متجر النخبة",type:"تجارة",icon:"◇",income:100},{name:"مزرعة الطاقة",type:"طاقة",icon:"ϟ",income:0}]};
let state = load();
let toastTimer;
function load(){try{const v=JSON.parse(localStorage.getItem(KEY));if(v&&Array.isArray(v.businesses))return {...initial,...v}}catch(e){}return structuredClone(initial)}
function save(){try{localStorage.setItem(KEY,JSON.stringify(state))}catch(e){toast("تعذر حفظ تقدمك على هذا الجهاز.")}}
function toast(message){const el=$("#toast");el.textContent=message;el.classList.add("show");clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove("show"),2300)}
function updateWallet(){ $("#cash").textContent=fmt(state.cash);$("#energy").textContent=state.energy+"/100";$("#materials").textContent=fmt(state.materials);$("#influence").textContent=fmt(state.influence);$("#asset-count").textContent=state.businesses.length;$("#hourly-income").textContent="+"+fmt(state.businesses.reduce((a,b)=>a+b.income,0));$("#team-power").textContent=fmt(1280+state.battles*25);$("#army-power").textContent=fmt(1280+state.battles*25);$("#mission-progress").style.width=state.businesses.length>4?"100%":"50%";$("#battle-progress").style.width=Math.min(100,state.battles*50)+"%")}
function renderBusinesses(){const el=$("#business-list");el.innerHTML="";state.businesses.forEach((b,i)=>{const card=document.createElement("article");card.className="business-card";card.innerHTML='<span class="business-art"></span><div class="business-copy"><b></b><small></small></div><div class="business-income"><b></b><small>دخل / ساعة</small></div>';$(".business-art",card).textContent=b.icon;$(".business-copy b",card).textContent=b.name;$(".business-copy small",card).textContent=b.type+" · المستوى "+(i===0?3:1);$(".business-income b",card).textContent="+"+fmt(b.income)+" ◈";el.append(card)})}
const goods=[{name:"سبائك معدنية",icon:"⬡",price:42,change:"+4.8%"},{name:"مكوّنات إلكترونية",icon:"▦",price:68,change:"+2.1%"},{name:"وقود صناعي",icon:"ϟ",price:31,change:"−1.4%"},{name:"مواد غذائية",icon:"✿",price:18,change:"+0.7%"}];
function renderMarket(){const el=$("#market-list");el.innerHTML="";goods.forEach(g=>{const row=document.createElement("article");row.className="market-item";row.innerHTML='<span class="good-icon"></span><div class="good-copy"><b></b><small>السعر لكل وحدة</small></div><div class="good-price"><b></b><small></small></div>';$(".good-icon",row).textContent=g.icon;$(".good-copy b",row).textContent=g.name;$(".good-price b",row).textContent=g.price+" ◈";$(".good-price small",row).textContent=g.change;$(".good-price small",row).style.color=g.change.startsWith("−")?"#e58b82":"#7ee0c0";el.append(row)})}
function showDialog(kicker,title,message,icon="✦"){ $("#dialog-kicker").textContent=kicker;$("#dialog-title").textContent=title;$("#dialog-text").textContent=message;$("#dialog-icon").textContent=icon;$("#result-dialog").showModal()}
function go(view){const target=$("#view-"+view);if(!target)return;$$(".view").forEach(v=>v.classList.toggle("active",v===target));$$(".nav-item").forEach(b=>b.classList.toggle("active",b.dataset.view===view));window.scrollTo({top:0,behavior:"smooth"});if(view==="empire")renderBusinesses()}
$$(".nav-item").forEach(b=>b.addEventListener("click",()=>go(b.dataset.view)));
$$("[data-go]").forEach(b=>b.addEventListener("click",()=>go(b.dataset.go)));
$("#profile-open").addEventListener("click",()=>go("profile"));
$("#buy-business").addEventListener("click",()=>{if(state.cash<5000)return toast("تحتاج إلى 5,000 رصيد لشراء منشأة.");state.cash-=5000;state.businesses.push({name:"استوديو نوفا",type:"خدمات رقمية",icon:"✧",income:160});save();updateWallet();renderBusinesses();toast("تمت إضافة منشأة جديدة إلى إمبراطوريتك.")});
$("#quick-buy").addEventListener("click",()=>{if(state.cash<500)return toast("رصيدك غير كافٍ.");state.cash-=500;state.materials+=50;save();updateWallet();toast("وصلت 50 مادة إلى مخزونك.")});
$("#simulate-battle").addEventListener("click",()=>{if(state.energy<15)return toast("تحتاج إلى 15 طاقة لبدء المحاكاة.");state.energy-=15;state.battles++;const power=1280+state.battles*25;const win=power>=1220;const reward=win?650:180;state.cash+=reward;state.influence+=win?18:5;save();updateWallet();showDialog("تقرير المواجهة",win?"انتصار تكتيكي!":"انسحاب منظم", "انتهت المحاكاة التدريبية. قوة فريقك "+fmt(power)+" مقابل 1,220. المكافأة: "+fmt(reward)+" رصيد و"+(win?18:5)+" نفوذ.","⚔")});
$("#guild-chat").addEventListener("click",()=>showDialog("مجتمع روّاد الفجر","الدردشة قيد التجهيز","واجهة المجتمع معروضة كنموذج بصري. المحادثات الحقيقية ستُربط بقنوات خاصة ومحمية عند تفعيل اللعب الجماعي.","✧"));
$$("[data-sector]").forEach(b=>b.addEventListener("click",()=>{const n=b.dataset.sector;$("#district-card").innerHTML='<div><span class="eyebrow">قطاع قابل للاستكشاف</span><h3>القطاع '+n+(n==="12"?" — ميناء الشمال":" — الحزام الصناعي")+'</h3><p>يمكنك إرسال استطلاع عند فتح نظام التنقل.</p></div><span class="owned-pill">متاح</span>';toast("تم تحديد القطاع "+n)}));
$("#dialog-close").addEventListener("click",()=>$("#result-dialog").close());
$$(".settings-list button").forEach(b=>b.addEventListener("click",()=>toast("هذه الميزة ضمن مراحل التطوير التالية.")));
updateWallet();renderBusinesses();renderMarket();
})();