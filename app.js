(() => {
  "use strict";
  const STORAGE_KEY = "nova-first-prototype-v1";
  const initialState = {
    resources: { food: 1250, wood: 980, stone: 720, iron: 360, gold: 150 },
    buildings: { keep: 1, farm: 1, lumber: 1, barracks: 1 },
    items: { advanced: 1, random: 1, supplies: 2 },
    castle: 25,
    collected: false,
    visitedMap: false,
    selectedTile: 17,
    completed: {},
    relocationMode: false
  };
  const buildingData = {
    keep: { name: "القصر", costs: { wood: 180, stone: 120, gold: 20 } },
    farm: { name: "المزرعة", costs: { wood: 90, stone: 35 } },
    lumber: { name: "منشرة الخشب", costs: { wood: 70, stone: 45 } },
    barracks: { name: "الثكنة", costs: { wood: 120, stone: 90, iron: 35 } }
  };
  const resourceNames = { food: "الطعام", wood: "الخشب", stone: "الحجر", iron: "الحديد", gold: "الذهب" };
  const tileTypes = [
    "plain","forest","plain","village","plain","water","plain",
    "plain","resource","plain","plain","forest","plain","ruin",
    "forest","plain","plain","plain","resource","plain","plain",
    "plain","water","plain","plain","plain","village","plain",
    "plain","plain","ruin","plain","plain","forest","plain",
    "village","plain","resource","plain","plain","plain","water",
    "plain","forest","plain","plain","village","plain","plain"
  ];
  const tileInfo = {
    plain: { name: "أرض خضراء", description: "مساحة مفتوحة مناسبة للاستقرار وبناء قلعتك.", type: "أرض صالحة", icon: "·" },
    forest: { name: "غابة الصنوبر", description: "غابة هادئة تحيط بها أشجار كثيفة.", type: "غابة", icon: "♣" },
    village: { name: "قرية الوادي", description: "تجمع صغير يمكن أن يصبح مركزاً للتجارة والمهام.", type: "قرية", icon: "⌂" },
    resource: { name: "مكمن الموارد", description: "موقع غني بالموارد ويستحق الاستكشاف.", type: "موارد", icon: "◆" },
    ruin: { name: "أطلال قديمة", description: "آثار من زمن المملكة السابقة؛ أسرارها لم تُكشف بعد.", type: "أطلال", icon: "⌑" },
    water: { name: "بحيرة صافية", description: "مياه تعبر المنطقة. لا يمكن بناء قلعة فوقها.", type: "مياه", icon: "≈" }
  };
  let state = loadState();
  let toastTimer;
  let confirmHandler = null;
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const number = value => new Intl.NumberFormat("ar").format(value);

  function loadState() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
      if (saved && saved.resources && saved.buildings && saved.items) {
        return { ...structuredClone(initialState), ...saved, relocationMode: false };
      }
    } catch (_) {}
    return structuredClone(initialState);
  }
  function save() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }
    catch (_) { showToast("تعذر حفظ التقدم على هذا الجهاز."); }
  }
  function showToast(message) {
    const el = $("#toast");
    el.textContent = message;
    el.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove("show"), 2600);
  }
  function showConfirm({ title, description, symbol = "✦", confirm = "تأكيد", action }) {
    $("#dialog-title").textContent = title;
    $("#dialog-description").textContent = description;
    $("#dialog-symbol").textContent = symbol;
    $("#dialog-confirm").textContent = confirm;
    confirmHandler = action;
    $("#confirm-dialog").showModal();
  }
  function switchScreen(name) {
    $$(".screen").forEach(screen => screen.classList.toggle("active", screen.id === `screen-${name}`));
    $$(".nav-item").forEach(button => button.classList.toggle("active", button.dataset.screen === name));
    if (name === "map") { state.visitedMap = true; checkQuests(); save(); renderQuests(); }
    if (name === "profile") renderProfile();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
  function canAfford(costs) {
    return Object.entries(costs).every(([key, amount]) => state.resources[key] >= amount);
  }
  function costLabel(costs) {
    return Object.entries(costs).map(([key, amount]) => `${number(amount)} ${resourceNames[key]}`).join(" · ");
  }
  function upgradeBuilding(key) {
    const level = state.buildings[key];
    const factor = level;
    const costs = Object.fromEntries(Object.entries(buildingData[key].costs).map(([resource, amount]) => [resource, amount * factor]));
    if (level >= 5) return showToast("وصل المبنى إلى الحد الأعلى في هذا النموذج.");
    if (!canAfford(costs)) return showToast("مواردك لا تكفي لهذا التطوير.");
    showConfirm({
      title: `تطوير ${buildingData[key].name}`,
      description: `المستوى الحالي ${number(level)} ← ${number(level + 1)}. التكلفة: ${costLabel(costs)}.`,
      symbol: "⚒",
      confirm: "ابدأ التطوير",
      action: () => {
        Object.entries(costs).forEach(([resource, amount]) => state.resources[resource] -= amount);
        state.buildings[key] += 1;
        save(); render();
        showToast(`تم تطوير ${buildingData[key].name} بنجاح.`);
      }
    });
  }
  function collectResources() {
    const yields = { food: 180, wood: 120, stone: 65, iron: 25 };
    const farmBonus = (state.buildings.farm - 1) * 25;
    const lumberBonus = (state.buildings.lumber - 1) * 20;
    yields.food += farmBonus;
    yields.wood += lumberBonus;
    Object.entries(yields).forEach(([key, amount]) => state.resources[key] += amount);
    state.collected = true;
    save(); render();
    showToast("وصل إنتاج القلعة إلى مخازنك.");
  }
  function renderResources() {
    Object.entries(state.resources).forEach(([key, value]) => {
      const el = document.getElementById(`${key}-value`);
      if (el) el.textContent = number(value);
    });
  }
  function renderBuildings() {
    $$(".building-card").forEach(card => {
      const key = card.dataset.building;
      const level = state.buildings[key];
      const cost = Object.fromEntries(Object.entries(buildingData[key].costs).map(([resource, amount]) => [resource, amount * level]));
      const button = $("[data-upgrade]", card);
      $(".building-level b", card).textContent = number(level);
      button.disabled = level >= 5 || !canAfford(cost);
      button.textContent = level >= 5 ? "مكتمل" : "تطوير";
    });
    $("#keep-level").textContent = number(state.buildings.keep);
    $("#building-count").textContent = `${number(Object.keys(state.buildings).length)} مبانٍ`;
  }
  function renderMap() {
    const grid = $("#map-grid");
    grid.innerHTML = "";
    tileTypes.forEach((type, index) => {
      const tile = document.createElement("button");
      tile.type = "button";
      tile.className = `map-tile ${type}${state.castle === index ? " castle" : ""}${state.selectedTile === index ? " selected" : ""}`;
      tile.setAttribute("role", "gridcell");
      tile.setAttribute("aria-label", state.castle === index ? "قلعتك" : tileInfo[type].name);
      tile.textContent = state.castle === index ? "♜" : tileInfo[type].icon;
      if (type === "water") tile.disabled = true;
      tile.addEventListener("click", () => selectTile(index));
      grid.appendChild(tile);
    });
    const row = Math.floor(state.castle / 7) + 1;
    const col = state.castle % 7 + 1;
    $("#castle-location").textContent = `الإحداثيات: ${number(row)} : ${number(col)}`;
    $("#map-coordinates").textContent = `${number(row)} : ${number(col)}`;
    updateLocationCard(state.selectedTile);
  }
  function updateLocationCard(index) {
    const type = tileTypes[index];
    const info = tileInfo[type];
    $("#location-name").textContent = state.castle === index ? "قلعتك" : info.name;
    $("#location-description").textContent = state.castle === index ? "هنا موطنك ومركز تطورك في المملكة." : info.description;
    $("#location-type").textContent = state.castle === index ? "موقعك" : info.type;
  }
  function selectTile(index) {
    state.selectedTile = index;
    if (state.relocationMode) {
      if (index === state.castle) return showToast("هذه قلعتك الحالية.");
      if (tileTypes[index] !== "plain") return showToast("اختر أرضاً خضراء خالية لنقل القلعة.");
      showConfirm({
        title: "تأكيد موقع القلعة",
        description: "في اللعبة الكاملة سيتحقق الخادم من صلاحية الموقع والمسافات والحماية قبل استهلاك الغرض. هذا النموذج يغيّر موقعك المحلي فقط.",
        symbol: "⌖",
        confirm: "نقل القلعة",
        action: () => {
          if (state.items.advanced < 1) return showToast("لا تملك غرض نقل متقدماً.");
          state.items.advanced -= 1;
          state.castle = index;
          state.relocationMode = false;
          save(); render();
          showToast("تم نقل قلعتك في النموذج التجريبي.");
        }
      });
      return;
    }
    renderMap();
  }
  function availableTiles() {
    return tileTypes.map((type, index) => ({ type, index })).filter(tile => tile.type === "plain" && tile.index !== state.castle);
  }
  function useRandomRelocation() {
    if (state.items.random < 1) return showToast("لا تملك غرض نقل عشوائياً.");
    const candidates = availableTiles();
    if (!candidates.length) return showToast("لا توجد مواقع صالحة حالياً.");
    const destination = candidates[Math.floor(Math.random() * candidates.length)];
    showConfirm({
      title: "نقل عشوائي",
      description: `سيختار النموذج موقعاً صالحاً لك: ${number(Math.floor(destination.index / 7) + 1)} : ${number(destination.index % 7 + 1)}. في اللعبة الكاملة يحدد الخادم الموقع ويعيد التحقق منه.`,
      symbol: "✧",
      confirm: "استخدم الغرض",
      action: () => {
        state.items.random -= 1;
        state.castle = destination.index;
        state.selectedTile = destination.index;
        save(); render();
        switchScreen("map");
        showToast("انتقلت قلعتك إلى موقع جديد في النموذج.");
      }
    });
  }
  function useSupplies() {
    if (state.items.supplies < 1) return showToast("لا تملك حزمة مؤن.");
    showConfirm({
      title: "استخدام حزمة المؤن",
      description: "ستضيف الحزمة 250 طعاماً و150 خشباً إلى مخزونك.",
      symbol: "✿",
      confirm: "استخدام",
      action: () => {
        state.items.supplies -= 1;
        state.resources.food += 250;
        state.resources.wood += 150;
        save(); render();
        showToast("أُضيفت المؤن إلى مخازنك.");
      }
    });
  }
  function renderInventory(filter = "all") {
    const items = [
      { id: "advanced", category: "relocation", name: "نقل متقدم", rarity: "نادر", description: "اختر موقعاً صالحاً على خريطة المملكة.", icon: "⌖", className: "relocation-art", action: "استخدام" },
      { id: "random", category: "relocation", name: "نقل عشوائي", rarity: "شائع", description: "انتقل إلى موقع صالح يختاره النظام.", icon: "✧", className: "random-art", action: "استخدام" },
      { id: "supplies", category: "boost", name: "حزمة مؤن", rarity: "شائع", description: "أضف موارد إلى مخزون قلعتك.", icon: "✿", className: "boost-art", action: "استخدام" }
    ].filter(item => filter === "all" || item.category === filter);
    const grid = $("#inventory-grid");
    grid.innerHTML = "";
    items.forEach(item => {
      const card = document.createElement("article");
      card.className = "item-card";
      const art = document.createElement("div"); art.className = `item-art ${item.className}`; art.textContent = item.icon;
      const copy = document.createElement("div"); copy.className = "item-copy";
      const rarity = document.createElement("span"); rarity.className = `item-rarity ${item.rarity === "شائع" ? "common" : ""}`; rarity.textContent = item.rarity;
      const title = document.createElement("h3"); title.textContent = item.name;
      const description = document.createElement("p"); description.textContent = item.description;
      const quantity = document.createElement("b"); quantity.textContent = `الكمية: ${number(state.items[item.id])}`;
      copy.append(rarity, title, description, quantity);
      const button = document.createElement("button"); button.className = "item-action"; button.textContent = item.action; button.disabled = state.items[item.id] < 1;
      button.addEventListener("click", () => {
        if (item.id === "advanced") {
          if (state.items.advanced < 1) return;
          state.relocationMode = true;
          switchScreen("map");
          showToast("اختر أرضاً خضراء خالية لنقل قلعتك.");
        } else if (item.id === "random") useRandomRelocation();
        else useSupplies();
      });
      card.append(art, copy, button); grid.appendChild(card);
    });
    $("#bag-capacity").textContent = `${number(Object.values(state.items).reduce((sum, amount) => sum + amount, 0))} / 20`;
  }
  function checkQuests() {
    const goals = {
      keep: state.buildings.keep >= 2,
      supplies: state.collected,
      map: state.visitedMap
    };
    const rewards = { keep: { gold: 100 }, supplies: { food: 150 }, map: { wood: 80 } };
    Object.entries(goals).forEach(([key, done]) => {
      if (done && !state.completed[key]) {
        state.completed[key] = true;
        Object.entries(rewards[key]).forEach(([resource, amount]) => state.resources[resource] += amount);
      }
    });
  }
  function renderQuests() {
    const quests = [
      { id: "keep", title: "أعد بناء القصر", description: "طوّر مركز قلعتك إلى المستوى الثاني.", reward: "100 ذهب" },
      { id: "supplies", title: "أمّن المؤونة", description: "اجمع الموارد من مخزون الإنتاج.", reward: "150 طعام" },
      { id: "map", title: "اكتشف المملكة", description: "افتح الخريطة وتفقد مواقعها.", reward: "80 خشب" }
    ];
    const list = $("#quest-list"); list.innerHTML = "";
    quests.forEach(quest => {
      const done = Boolean(state.completed[quest.id]);
      const card = document.createElement("article"); card.className = `quest-card${done ? " done" : ""}`;
      const symbol = document.createElement("span"); symbol.className = "quest-symbol"; symbol.textContent = quest.id === "keep" ? "⌂" : quest.id === "supplies" ? "✿" : "⌖";
      const content = document.createElement("div");
      const title = document.createElement("h3"); title.textContent = quest.title;
      const description = document.createElement("p"); description.textContent = quest.description;
      const reward = document.createElement("span"); reward.className = "quest-reward"; reward.textContent = `المكافأة: ${quest.reward}`;
      content.append(title, description, reward);
      const status = document.createElement("span"); status.className = "quest-state"; status.textContent = done ? "مكتملة ✓" : "قيد التنفيذ";
      card.append(symbol, content, status); list.appendChild(card);
    });
    const completed = Object.values(state.completed).filter(Boolean).length;
    $("#quest-progress").textContent = `${number(completed)} / 3`;
  }
  function renderProfile() {
    $("#profile-keep-level").textContent = number(state.buildings.keep);
    $("#profile-buildings").textContent = number(Object.keys(state.buildings).length);
    $("#profile-quests").textContent = number(Object.values(state.completed).filter(Boolean).length);
  }
  function render() {
    checkQuests();
    renderResources(); renderBuildings(); renderMap(); renderInventory($(".inventory-tab.active")?.dataset.filter || "all"); renderQuests(); renderProfile();
  }

  $$(".nav-item").forEach(button => button.addEventListener("click", () => switchScreen(button.dataset.screen)));
  $("#profile-button").addEventListener("click", () => switchScreen("profile"));
  $$(".upgrade-button").forEach(button => button.addEventListener("click", () => upgradeBuilding(button.dataset.upgrade)));
  $("#collect-button").addEventListener("click", collectResources);
  $$(".inventory-tab").forEach(button => button.addEventListener("click", () => {
    $$(".inventory-tab").forEach(tab => tab.classList.toggle("active", tab === button));
    renderInventory(button.dataset.filter);
  }));
  $("#dialog-cancel").addEventListener("click", () => $("#confirm-dialog").close());
  $("#dialog-confirm").addEventListener("click", () => {
    const action = confirmHandler; confirmHandler = null; $("#confirm-dialog").close();
    if (action) action();
  });
  $("#reset-button").addEventListener("click", () => showConfirm({
    title: "إعادة ضبط النموذج؟",
    description: "سيتم حذف التقدم المحلي وإعادة القلعة والموارد والأغراض إلى حالتها الأولى على هذا الجهاز.",
    symbol: "↺",
    confirm: "إعادة الضبط",
    action: () => { state = structuredClone(initialState); save(); render(); switchScreen("castle"); showToast("تمت إعادة ضبط النموذج."); }
  }));

  render();
})();