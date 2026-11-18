# NOVA / NEXORA — نقل المشروع (2026-11-18)

> **هذه الملاحظة هي الحالة الأحدث وتعلو على تفاصيل سجل التطوير التاريخي أدناه.**

- تم استبدال محتوى مستودع `powerx911/NOVA` بنسخة NEXORA الأصلية كاملة، ودمجها إلى `main` في commit `1686aa3995561560cd52eee798401507ba2c8c9e`.
- نُقلت 83 ملفاً من المصدر، بما فيها الأصول والصور. فحوص CI على طلب الدمج نجحت: TypeScript، قواعد Firestore، Deno، الاختبارات، بناء الواجهة، وبناء Cloud Functions.
- مشروع Supabase المستهدف هو `NOVA` (`hmrprnjhyzyefocdmnxf`) وليس مشروع OneState القديم.
- تم إنشاء `nexora` schema مع 23 جدولاً. جميع الجداول مفعّل عليها RLS، ولا توجد صلاحيات وصول مباشرة لـ`anon` أو `authenticated`. هويات Firebase محفوظة كـ`text` لتوافق UID الحالي.
- أُزيلت جداول ووظائف NOVA القديمة بعد التحقق من أن الجداول القديمة الـ17 كانت فارغة. لم يتم حذف مستخدمي Supabase Auth أو تعديل مخططات Supabase المُدارة.
- تم تعطيل خدمة `nova-control` القديمة؛ endpoint القديم يعيد `410` ويتطلب JWT.
- أُضيف workflow يدوي للنشر إلى GitHub Pages مع base path `/NOVA/`، لكنه **لم يُشغّل** بعد.
- **ما لم يكتمل بعد:** التطبيق ما زال يستخدم Firebase Auth وFirestore لمصدر بيانات اللعب. يلزم نقل عمليات القراءة والكتابة الاقتصادية إلى عمليات Supabase موثوقة واختبارها قبل تشغيل Pages workflow أو اعتبار اللعبة جاهزة للإنتاج.
- لا تُشغّل أدوات تصدير/استيراد Firestore من المشروع الأصلي، ولا تعدّل مشروع Firebase الأصلي. لا تُفعّل النشر قبل اكتمال نقل backend.

---

# حالة مشروع NEXORA — المرجع الرسمي (`PROJECT_STATUS.md`)

> آخر تحديث: `2026-11-16`  
> الإصدار الوظيفي الموثق: `1.1.1` (تغييرات السمعة والأحداث موجودة على فرع التطوير ولم تُعتمد كإصدار بعد)  
> المستودع المستهدف: `https://github.com/luffyk124-del/nexora-game`

---

## 1. نظرة عامة
- **فكرة اللعبة**: **NEXORA** لعبة محاكاة اقتصادية وإدارة شركات واستراتيجية اجتماعية تعمل داخل المتصفح بتصميم **Mobile-First (Portrait)**، تتيح للاعب البدء من الصفر وبناء ثروته ونفوذه وشركاته وعقاراته ومنظماته عبر اقتصاد مترابط وقرارات ذات أثر فعلي.
- **الأهداف**:
  - تقديم دورة لعب مترابطة (تجارة، تصنيع، شركات، عقارات، مهارات، منظمات، مهام، وتصنيفات).
  - ضمان سلامة الأرصدة ومنع التلاعب عبر معاملات Firestore الذرية وقواعد أمان صارمة.
  - واجهة عربية أصلية (`RTL`) مع دعم تبديل فوري إلى الإنجليزية (`LTR`).
- **التقنيات الرسمية المعتمدة**:
  - الواجهة: React 19, TypeScript, Vite 8, Tailwind CSS v4, Lucide Icons, Motion.
  - الخلفية والبيانات: **Firebase Authentication (Google Sign-In)** و**Cloud Firestore (Enterprise Edition)** كمنصة رسمية وحيدة للمشروع.
  - التحقق والاختبار: Vitest, TypeScript (`tsc --noEmit`), `@firebase/eslint-plugin-security-rules`.
- **المنصة المستهدفة**: متصفحات الهواتف بوضع عمودي (Portrait) أساساً، مع استجابة كاملة لسطح المكتب.

---

## 2. الحالة الحالية
- **الحالة الحالية**: فرع `development/nexora-next` هو فرع التطوير النشط. آخر نشر موثق قبل تغييرات المصادقة الأخيرة كان `READY`، أما نشر commit `b3c82abb6193f4bc3f3999ad1cb565f0c809e21a` فيجري التحقق منه؛ لا تعتبر حالة `READY` وحدها دليلاً على نجاح تسجيل Google أو اتصال WIF/Firestore الحي. أكد مالك المشروع سابقاً نجاح نشر قواعد Firestore.
- **المرحلة الحالية**: استكمال التحقق الحي من أنظمة اللعبة ومراجعة ما قبل اعتماد الإصدار التالي. فرع `development/nexora-next` هو فرع العمل، ولا يُدمج شيء إلى `main` تلقائياً.
- **آخر نقطة وصل إليها التطوير**:
  - آخر commit مستقر على `main` وقت إنشاء بيئة التطوير: `178ef86422bd31c3867e283e44d2a0421668cf74`، ويضيف نظام مستويات السمعة ومكافآتها، ويطوّر الأحداث العالمية بمدد زمنية ومجموعات تأثير وقطاعات مستهدفة، ويضيف مؤشر حالة الاتصال.
  - تم إنشاء فرع عمل مستقل `development/nexora-next`. فحوص CI الأخيرة على commit `ad299d3ffac3e8ee276e6ab122917a74309cd9db` ناجحة وفق تأكيد المستخدم.
  - تشديد `firestore.rules` محلياً (`company_hire` المستقل، سقف رسوم السوق، مطابقة `itemId` وكمية العرض عند الشراء، قصر `manufacturing` على الوصفات الرسمية، ربط `market_orders` بمعاملة المحفظة، وتقييد `organization_requests` `allow list` بصلاحية `manage_members`).
  - إصلاح دورة الحياة في `useGameData.ts` (تصفير كامل عند تسجيل الخروج، اشتراك `myPendingOrgIds`، تحديث `utcDateKey` تلقائياً عند منتصف الليل UTC، ومنع تكرار محاولات الإنجازات) وتوحيد حدود الاقتصاد وحسابات المهام والإنجازات في `economy.ts` و`gameService.ts`.
  - تحسين الواجهة في جميع التبويبات الستة (`Auth`, `Home`, `Business`, `Market`, `Organization`, `Profile`)، وتعريب أنواع المعاملات والرتب وفئات المهام، وإضافة حالات التحميل والخطأ والحدود القصوى (`MAX`)، وتقسيم حزم البناء في `vite.config.ts`.
  - إضافة اختبارات المراجعة ومحرك الأحداث العالمية، وإصلاح اختبار حدود أسعار السوق باحتساب الحد من السعر المعدل بالعرض قبل التقريب النهائي؛ لم يتغير منطق الاقتصاد الإنتاجي.

---

## 3. الأنظمة المنفذة (فعلياً في الكود)
| النظام | الحالة | الوصف المختصر |
| :--- | :--- | :--- |
| **المصادقة وإنشاء الشخصية** | منفذ (`src/features/auth/AuthOnboardingView.tsx`) | تسجيل الدخول عبر Google (`signInWithPopup`)، حجز اسم مستخدم فريد في `usernames`، اختيار صورة رمزية، وإيداع `2,500 $` + `3` نقاط مهارة. |
| **الهيكل العام والتنقل** | منفذ (`src/components/ui/AppShell.tsx`) | شريط علوي ثابت يعرض الرصيد والمستوى والإشعارات، وشريط تنقل سفلي من 5 أقسام (`الرئيسية`, `الأعمال`, `السوق`, `المنظمة`, `الشخصية`)، ودعم `RTL/LTR`. |
| **لوحة الرئيسية والعمليات اليومية** | منفذ (`src/features/home/HomeDashboardView.tsx`) | عرض ملف اللاعب والخبرة والمستوى، صرف العائد اليومي (`claimDailyStipend`) لمرة واحدة يومياً، رسم بياني لأسعار السوق، الأحداث العالمية، المهام النشطة، وسجل المعاملات. |
| **الشركات والعقارات والتصنيع** | منفذ (`src/features/business/BusinessHubView.tsx`) | تأسيس شركات في 5 قطاعات، الترقية، توظيف الموظفين، خزينة أرباح مستقلة لكل شركة بمستويات وسعات وترقيات بالمال والمواد، تحصيل العائد الساعي التراكمي؛ شراء العقارات وتأجيرها وترقيتها؛ سلاسل تصنيع 3 مستويات. |
| **السوق المفتوح والعقود والتحويلات** | منفذ (`src/features/market/MarketHubView.tsx`) | عرض وطلب الموارد بأسعار ديناميكية وضريبة سوق متأثرة بمهارة التجارة والأحداث العالمية، شراء/بيع/إلغاء العروض، عقود تجارية يومية، وتحويلات مالية بين اللاعبين. |
| **المنظمات والصلاحيات (RBAC)** | منفذ (`src/features/organization/OrganizationHubView.tsx`) | تأسيس المنظمات، إرسال وقبول/رفض طلبات الانضمام، إدارة الرتب (`leader`, `deputy`, `officer`, `member`)، وخزينة مشتركة بالإيداع والسحب وسجل عمليات المنظمة. |
| **الملف الشخصي والمهارات والتصنيفات** | منفذ (`src/features/profile/ProfileHubView.tsx`) | شجرة 6 مهارات مؤثرة حسابياً (`trade`, `management`, `industry`, `negotiation`, `finance`, `leadership`)، المهام (تعليمية/يومية/أسبوعية/موسمية)، الإنجازات، التصنيفات (النفوذ/الشركات/المنظمات)، والإعدادات. |
| **محرك الحسابات الاقتصادية** | منفذ ومختبر (`src/lib/economy.ts`) | حسابات حتمية للضرائب، التسعير الديناميكي، صافي ربح الشركات والعقارات، تكلفة التصنيع، المستويات، والتحويلات. |
| **نظام التشخيص والمراقبة الآمن** | الواجهة جاهزة؛ الخلفية غير منشورة | لوحة قرائية مقيدة بالمالك مع تصدير JSON. استدعاء الخلفية الحالي يعتمد على Cloud Functions Gen 2، ويحتاج نقله إلى Vercel قبل التحقق الإنتاجي. |

---

## 4. الأنظمة قيد التطوير والتحقق
- **قواعد Firestore**: تم نشر القواعد المحدثة بنجاح وفق تأكيد مالك المشروع، وأصبحت خطوة النشر مغلقة.
- **التشخيص**: واجهة التشخيص وكود Cloud Function Gen 2 موجودان، لكن نشر `nexoraDiagnostics` وصلاحية المالك غير متحققين. لا تنشر Cloud Functions أو تفعّل Billing/Blaze؛ يلزم نقل التشخيص إلى مسار Vercel آمن قبل اعتباره جاهزاً.
- **التطوير والنشر**: العمل مستمر على `development/nexora-next` فقط. لا تدمج إلى `main` دون اعتماد صريح، ولا تخلط بين Preview وProduction.

---

## 5. الأنظمة المخطط لها (لم يبدأ تنفيذها)
- التحالفات والاتفاقيات الرسمية بين المنظمات (Organization Alliances & Treaties).
- أهداف وتحديات جماعية أسبوعية/موسمية على مستوى المنظمة.
- عناصر تجميلية قابلة للفتح والشارات المخصصة للملفات الشخصية.
- سجل تاريخي زمني ممتد لأسعار السلع ووظائف خلفية مجدولة عبر Cloud Functions عند الحاجة للتوسع.

---

## 6. قاعدة البيانات (Cloud Firestore)
- **معرّف قاعدة البيانات**: `ai-studio-74843d9e-8228-49b7-a616-317cadd90bff` (في مشروع `gen-lang-client-0074900177`).
- **المجموعات المعتمدة** (موثقة بالتفصيل في `firebase-blueprint.json` و`docs/DATABASE.md`):
  - `test/connection`: نقطة فحص الاتصال بالخادم.
  - `profiles/{uid}` و`usernames/{usernameLower}` و`users_private/{uid}`: فصل البيانات العامة عن PII وحجز الأسماء الفريدة.
  - `wallets/{uid}` و`transactions/{txId}`: المحافظ والسجل المالي غير القابل للتعديل (`append-only`).
  - `inventory/{uid}_{itemId}` و`market_listings/{listingId}` و`market_orders/{orderId}`: المخزون وعروض السوق وأوامر الشراء المنفذة.
  - `companies/{companyId}` و`company_logs/{logId}` و`properties/{propertyId}`: أصول الشركات والعقارات وسجلاتها.
  - `organizations/{orgId}` و`organization_members/{orgId}_{uid}` و`organization_requests/{reqId}` و`organization_transactions/{txId}`: المنظمات والصلاحيات والخزينة.
  - `player_missions/{uid}_{missionId}` و`daily_claims/{uid}_{dateKey}` و`contract_claims/{uid}_{contractId}` و`player_achievements/{uid}_{achievementId}`: أقفال المطالبات والإنجازات.
  - `notifications/{notifId}` و`world_events/{eventId}` و`audit_logs/{logId}`: الإشعارات والأحداث العالمية وسجل التدقيق.
  - `diagnostics_admins/{uid}`: سجل قرائي مدار إدارياً لصلاحيات مالك التشخيص (`allow list, create, update, delete: if false`).
- **العلاقات والفهارس**: جميع قوائم التصنيف والمنظمات تجمع `where(field, '>=', 0)` مع `orderBy(field, 'desc')` على نفس الحقل لاستخدام الفهارس الأحادية تلقائياً دون فشل فهارس مركبة، كما تخضع جميع قواعد `allow list` لقيود صريحة على `resource.data`.

---

## 7. المصادقة والمستخدمون
- تسجيل الدخول عبر **Google Sign-In**. على جميع الأجهزة يبدأ التطبيق الآن بـ`signInWithPopup` لتجنب فقدان جلسة التحويل على الهاتف؛ التحويل `signInWithRedirect` احتياطي عند حظر النافذة المنبثقة. نجاح هذا التعديل ما زال بانتظار اختبار المستخدم بعد النشر.
- جميع عمليات القراءة والكتابة في `firestore.rules` (عدا `test/connection`) تشترط `request.auth != null && request.auth.token.email_verified == true`.
- بيانات PII (`email`) معزولة بالكامل في `users_private/{uid}` (قراءة وتعديل المالك فقط).

---

## 8. الأمان والصلاحيات
- **إزالة قواعد `allow list: if isSignedIn();` المفتوحة**: جميع المجموعات أصبحت تقيد قوائمها عبر شروط `resource.data` (الملكية، الحالة `'active'` / `'pending'`، النطاق `>= 0`، أو `uid`/`orgId`).
- **منع التعديل المباشر من العميل على الأرصدة والتقدم**:
  - `wallets/{uid}`: يتطلب إنشاء `transactions/{txId}` ذرية متطابقة الحسابات (`isWalletDeltaValid` + `isAuthorizedTransaction`).
  - `profiles/{uid}`: مقسم إلى 4 إجراءات (`affectedKeys`)؛ زيادة `xp`/`level`/`skillPoints`/`reputation`/`influence` تتطلب معاملة محفظة ذرية (`hasNewWalletTx`).
  - `inventory/{docId}`: يمنع توليد العناصر مجاناً؛ أي زيادة تتطلب `market_buy` أو `manufacturing` أو إلغاء عرض سوق موثق (`lastListingId`).
  - `market_listings/{listingId}`: الإنشاء يخصم المخزون، الشراء يتحقق من `market_buy` في المحفظة، والإلغاء يرد المخزون ذرياً.
  - `companies` و`properties`: الأرباح/الإيجارات الأساسية ومصاريف الصيانة ثابتة لا تُعدل من العميل، والترقية والتوظيف والتحصيل تتطلب معاملات محفظة ذرية مع حد زمني نسبي لتحصيل الإيراد (`request.time - lastCollectedAt`).
  - `organizations`: الإيداع والسحب مقترنان بـ `org_deposit` / `org_withdraw`، وصلاحيات الإدارة مفروضة خادمياً عبر `hasOrgPermission`.
  - `diagnostics_admins/{uid}` و`nexoraDiagnostics`: وصول مقيد بالمالك فقط، قراءة فقط، رفض التعديل والاستعلامات العشوائية، وتنقيح الأسرار وPII.

---

## 9. الملفات المهمة
- `index.html`, `metadata.json`, `src/index.css`, `src/main.tsx`, `src/App.tsx`: نقطة الدخول والهوية البصرية.
- `src/types/game.ts`: نماذج البيانات TypeScript.
- `src/data/catalog.ts`: الكتالوج الثابت للسلع والوصفات والقطاعات والعقارات والمهام والأحداث.
- `src/lib/economy.ts`, `src/lib/diagnosticsSanitizer.ts`: محرك الحسابات الاقتصادية ومنقّح الأسرار ومراقب الأخطاء.
- `src/lib/firebase.ts`: تهيئة Firebase Auth وFirestore وFunctions وفحص الاتصال ومعالج الأخطاء `handleFirestoreError`.
- `src/services/gameService.ts`, `src/services/diagnosticsService.ts`: المعاملات الذرية لعمليات اللعبة وخدمة التشخيص القرائية.
- `src/hooks/useGameData.ts`: مستمعو `onSnapshot` وإدارة الجلسة وصلاحيات الاستماع.
- `src/i18n/translations.ts`: نصوص الواجهة العربية والإنجليزية.
- `src/features/*` و`src/components/ui/*`: شاشات ومكونات الواجهة بما فيها `src/features/diagnostics/DiagnosticsView.tsx`.
- `functions/src/index.ts`, `functions/src/diagnosticsCore.ts`, `firebase.json`: دالة Cloud Functions Gen 2 ونواتها الأمنية.
- `firestore.rules`, `firebase-blueprint.json`, `security_spec.md`, `eslint.config.js`: القواعد والمخطط ومواصفات الأمان.
- `src/tests/economy.test.ts`, `src/tests/diagnostics.test.ts`, `src/tests/audit.test.ts`: اختبارات Vitest (`27` اختباراً إجمالياً).
- `README.md`, `CHANGELOG.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/DIAGNOSTICS.md`, `PROJECT_STATUS.md`: التوثيق الرسمي الموحد.

---

## 10. الاختبارات والتحقق
- `npm run lint:rules` (`eslint firestore.rules`): ناجح (خروج `0`، 0 أخطاء، 0 تحذيرات).
- `npx tsc --noEmit`: ناجح (خروج `0`، 0 أخطاء).
- `npm run build --prefix functions`: ناجح (بناء `functions/lib/` دون أخطاء).
- `npm run test` (`vitest run`): ناجح (`27/27` اختباراً — `10/10` في `economy.test.ts` + `10/10` في `diagnostics.test.ts` + `7/7` في `audit.test.ts`).
- `npm run build` (`vite build`): ناجح (بناء `dist/` في `1.12s` مع تقسيم الحزم إلى `index` `222.28 kB` و`DiagnosticsView` الكسول `23.84 kB` و`react-vendor` `404.70 kB` و`firebase` `583.27 kB` و`icons` `33.17 kB`).
- **ملاحظة نشر محدثة (2026-11-16)**: أكد مالك المشروع نجاح نشر قواعد Firestore. نسخة Vercel للـcommit `ad299d3ffac3e8ee276e6ab122917a74309cd9db` في حالة `READY`. لا يوجد في سجل التحقق الحالي ما يثبت نشر Cloud Functions Gen 2.
- **مراجعة ما قبل النشر (`Pre-Deployment Audit`)**: تم تأكيد `projectId: gen-lang-client-0074900177` ووجود قاعدة البيانات المسماة `ai-studio-74843d9e-8228-49b7-a616-317cadd90bff` فعلياً عبر Firestore REST API، وتشديد فحص المالك بإزالة قبول `claims.admin === true` منفرداً واشتراط `claims.diagnosticsOwner === true` صراحةً، مع اشتراط `role === 'owner'` في `diagnostics_admins/{uid}` وإضافة `"database"` في `firebase.json`.

---

## 11. المشكلات المفتوحة والمغلقة
- **مغلقة**:
  - إغلاق ثغرات التعديل المباشر في `firestore.rules`، وفصل معاملات توظيف الكوادر (`company_hire`)، وتقييد `organization_requests` `allow list` على `manage_members`، وحماية `market_orders` و`inventory` عند الشراء والتصنيع.
  - معالجة حالات التسجيل الخروج، وتبديل الحسابات، وإشعارات الأخطاء، والتعريب الكامل، وتقسيم حزم البناء في الواجهة.
  - بناء نظام التشخيص والمراقبة الآمن (`NEXORA Diagnostics System`) مع حجب PII/الأسرار واختبار رفض غير المصرح لهم والتعديل والاستعلامات العشوائية، وتشديد `diagnosticsOwner`.
- **مفتوحة**:
  1. **Cloud Functions Gen 2**: التحقق من نشر `nexoraDiagnostics` ومنح المالك `diagnosticsOwner: true` أو سجل `diagnostics_admins/{uid}` قبل اعتبار التشخيص الخلفي مكتملاً.
  2. **اختبار حي داخل اللعبة**: مراجعة تسجيل الدخول، إنشاء الشخصية، المحافظ، السوق، الشركات وخزائن الأرباح، التصنيع، المنظمات، الإعدادات وتبديل اللغة على نسخة المعاينة.
  3. **اعتماد الإصدار**: مراجعة التغييرات المتراكمة على فرع التطوير قبل أي دمج إلى `main`.

---

## 12. القرارات التقنية
- **اعتماد Firebase Auth + Cloud Firestore كمنصة رسمية وحيدة**: توفير مصادقة Google فورية، ومزامنة لحظية عبر `onSnapshot`، وتنفيذ ذري عبر `runTransaction` محمي بقواعد خادمية صارمة.
- **استخدام فهارس أحادية في استعلامات التصنيف**: الجمع بين `where(field, '>=', 0)` و`orderBy(field, 'desc')` على نفس الحقل لفرض قيود `allow list` دون الحاجة إلى فهارس مركبة يدوية.
- **فصل الحسابات الحتمية في `src/lib/economy.ts`**: لضمان اختبارها بـ Vitest وتوحيدها across UI & Services.
- **فصل صلاحية `diagnosticsOwner` عن `admin` العام**: منع منح صلاحية التشخيص بناءً على أي `admin: true` عام دون `diagnosticsOwner: true` أو سجل `diagnostics_admins/{uid}` (`enabled: true && role: 'owner'`).

---

## 13. سجل التحديثات
| التاريخ | الملفات المتأثرة | ما تغير | السبب | نتيجة التحقق |
| :--- | :--- | :--- | :--- | :--- |
| `2026-11-15` | `.github/workflows/ci.yml`, `PROJECT_STATUS.md` | إنشاء فرع التطوير `development/nexora-next` من آخر commit، وإضافة سير CI تلقائي لفحوص TypeScript وFirestore Rules وVitest وبناء الواجهة وCloud Functions، وتحديث سجل الحالة. | تجهيز بيئة تطوير معزولة عن `main` قبل استكمال التغييرات. | تم التحقق من وجود الفرع والملف على GitHub؛ نتائج CI لم تُسجل بعد. |
| `2026-11-15` | المشروع الأساسي بالكامل (`src/*`, `firestore.rules`, `firebase-blueprint.json`, `docs/*`) | بناء MVP المتكامل لـ NEXORA، قواعد الأمان، والاختبارات الأولية، ونشر القواعد الأولى. | تنفيذ وثيقة تصميم اللعبة GDD v1.0. | `lint:rules` ناجح، `vitest` `10/10`، `vite build` و`tsc` ناجحان. |
| `2026-11-15` | `firestore.rules`, `src/hooks/useGameData.ts` | تعديل `allow list` و`allow get` لـ `organizations`, `daily_claims`, `organization_members` وإضافة `handleFirestoreError` لمستمعي `onSnapshot`. | معالجة أخطاء `permission-denied` في مستمعي البداية. | تم نشر القواعد وبناء التطبيق. |
| `2026-11-15` | `src/hooks/useGameData.ts`, `firestore.rules`, `.gitignore`, `PROJECT_STATUS.md`, `CHANGELOG.md` | إضافة `orgMemberLoaded`، توسيع `.gitignore`، إنشاء `PROJECT_STATUS.md`، وتهيئة Git المحلي على `main` وربط `origin` (`d1613f7`, `5cf2bed`). | حل سباق تحميل عضوية المنظمة، وتأسيس التوثيق المستمر وربط Git. | `lint:rules`، `vitest`، `tsc`، `build`، و`DeployRules` ناجحة؛ `git push` محجوب لعدم توفر مصادقة GitHub. |
| `2026-11-15` | `firestore.rules`, `firebase-blueprint.json`, `src/services/gameService.ts`, `src/hooks/useGameData.ts`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `CHANGELOG.md`, `PROJECT_STATUS.md` | تشديد `firestore.rules` (إلغاء كل `allow list: if isSignedIn();`، وإغلاق ثغرات التلاعب في المحافظ والمخزون والسوق والشركات والعقارات والمنظمات والملف الشخصي)، تحديث استعلامات التصنيف و`cancelMarketListing` وقصر `organization_requests` على `manage_members`، نشر القواعد عبر `DeployRules`، وتوحيد التوثيق على Firebase. | تنفيذ الأولويات الخمس للمراجعة الأمنية الشاملة وتوحيد التوثيق والتحقق والرفع. | `npm run lint:rules` ناجح، `npm run test` (`10/10`)، `npx tsc --noEmit` ناجح، `npm run build` ناجح، `DeployRules` ناجح. |
| `2026-11-15` | `functions/*`, `firebase.json`, `firestore.rules`, `firebase-blueprint.json`, `src/lib/diagnosticsSanitizer.ts`, `src/services/diagnosticsService.ts`, `src/features/diagnostics/DiagnosticsView.tsx`, `src/features/profile/ProfileHubView.tsx`, `src/tests/diagnostics.test.ts`, `docs/DIAGNOSTICS.md`, `README.md`, `CHANGELOG.md`, `PROJECT_STATUS.md` | بناء **NEXORA Diagnostics System** (قراءة فقط ومقيد بالمالك، 5 أقسام، تصدير JSON منقّح، خادم Cloud Functions Gen 2، وقاعدة `diagnostics_admins/{uid}`). | إتاحة فحص صحة اللعبة وقاعدة البيانات واستخراج تقارير JSON آمنة خالية من الأسرار وPII. | `lint:rules` ناجح، `tsc --noEmit` ناجح، `functions` build ناجح، `vitest` (`20/20`)، `vite build` ناجح، `DeployRules` ناجح. |
| `2026-11-15` | `functions/src/diagnosticsCore.ts`, `functions/src/index.ts`, `src/services/diagnosticsService.ts`, `firebase.json`, `src/tests/diagnostics.test.ts`, `docs/DIAGNOSTICS.md`, `PROJECT_STATUS.md` | مراجعة ما قبل النشر: إزالة قبول `claims.admin === true` منفرداً واشتراط `claims.diagnosticsOwner === true`، التحقق من `role === 'owner'` في `diagnostics_admins/{uid}`، وتثبيت `database` في `firebase.json` (دون نشر). | تشديد التفويض بحيث لا يعتمد على `admin` العام وحده ومطابقة إعدادات قاعدة البيانات المسماة. | `lint:rules` ناجح، `tsc --noEmit` ناجح، `functions` build ناجح، `vitest` (`20/20`)، `vite build` ناجح. |
| `2026-11-15` | `firestore.rules`, `firebase-blueprint.json`, `vite.config.ts`, `src/types/game.ts`, `src/lib/economy.ts`, `src/services/gameService.ts`, `src/hooks/useGameData.ts`, `src/i18n/translations.ts`, `src/App.tsx`, `src/features/*`, `src/tests/audit.test.ts`, `README.md`, `CHANGELOG.md`, `docs/*`, `PROJECT_STATUS.md` | تنفيذ المراجعة الشاملة (`1.1.1`): فصل `company_hire` وتشديد قواعد `market_orders`/`inventory`/`organization_requests`، تصفير الحالة عند الخروج ودعم `myPendingOrgIds` وتحديث منتصف الليل UTC، تحسين أخطاء وحدود وحقول جميع الشاشات، تعريب السجل والرتب والمهام، التحميل الكسول لـ `DiagnosticsView` وتقسيم حزم `vite.config.ts`، وإضافة `audit.test.ts` (7 اختبارات). | رفع الأمان والاستقرار والأداء وتجربة اللعب وتغطية الاختبارات دون كسر البيانات الحالية أو نشر القواعد قبل الاعتماد. | `lint:rules` ناجح، `tsc --noEmit` ناجح، `functions` build ناجح، `vitest` (`27/27`)، `vite build` ناجح، `compile_applet` و`lint_applet` ناجحان. |


## 14. متابعة التطوير المباشر على GitHub
- أضيف الملف `src/tests/worldEventsEngine.test.ts` على فرع `development/nexora-next` في commit `d07e1d32ad2c901a49a755f7790d49ac383258a4`.
- يتضمن الملف 7 حالات اختبار لمحرك تدوير الأحداث: سقف عدد الأحداث، انتهاء الحدث عند حد الوقت، الحفاظ على الأحداث السارية، إزالة تكرار `stackGroup`، منع تعارض المجموعات، وتطابق مدة الحدث مع القالب.
- **حالة التحقق**: الاختبارات أضيفت ولم تُشغّل بعد داخل بيئة تنفيذ؛ لا تُحتسب ضمن الاختبارات الناجحة (27/27) حتى يكتمل GitHub Actions.
- **قرار الدمج**: لا دمج إلى `main` قبل نجاح CI ومراجعة قواعد Firestore وأثر التغييرات على بيانات اللاعبين الحالية.

- **إصلاح توافق البناء**: تم تحديث `esbuild` إلى `^0.28.2` لمطابقة peer dependency المطلوبة من Vite 8؛ التحقق الآلي بعد التعديل ما زال قيد الانتظار.


## 17. نظام الصوت والتفاعل اللمسي — 2026-11-15
- محرك صوت داخلي موحد في `src/lib/gameAudio.ts` باستخدام Web Audio API فقط؛ ينشئ `AudioContext` عند الحاجة ويعيد استخدامه بين الموسيقى ومؤثرات الواجهة.
- `GameAudioFeedback` يلتقط أول تفاعل موثوق (pointer أو keyboard) لمحاولة `AudioContext.resume()` ضمن مسار التفاعل، ثم يولّد نغمة قصيرة لكل زر/رابط تفاعلي عبر oscillators وgain envelopes. لا توجد ملفات MP3/WAV أو طلبات صوتية خارجية، ولا يبدأ الصوت قبل تفاعل المستخدم.
- الموسيقى الخلفية ومؤثرات الأزرار تشتركان في السياق الصوتي؛ إيقاف الموسيقى يخفض صوتها ويوقف تبديل الألحان دون تعطيل مؤثرات الواجهة.
- حالات ضغط مرئية وسريعة على اللمس والنقر، مع وضوح التركيز بلوحة المفاتيح واحترام `prefers-reduced-motion`.
- الفحص البنائي الجاري هو المرجع لاعتماد التغييرات؛ لا تنشر النسخة قبل نجاح TypeScript والاختبارات وبناء الواجهة والوظائف.

## 16. تحسينات العملة والموسيقى — 2026-11-15
- تم توحيد تسمية العملة المرئية إلى `$` في الشاشات الأساسية، دون تغيير أسماء الحقول أو قيم المحافظ أو معاملات Firestore أو منطق الاقتصاد.
- أضيفت موسيقى خلفية أصلية هادئة عبر Web Audio، مع انتقالات تآلفية بطيئة وزر تشغيل/إيقاف مستقل في الشريط العلوي؛ لا يتم تشغيل الصوت إلا بعد تفاعل اللاعب مع الزر احتراماً لقيود تشغيل الصوت في المتصفحات.
- تم إصلاح فرز دليل المنظمات باستخدام `memberCount` و`treasuryBalance` الفعليين بدلاً من مفاتيح غير موجودة على نموذج المنظمة.
- نتائج CI للتغييرات الحالية قيد التحقق؛ لا تُعد الدفعة جاهزة للنشر قبل نجاح جميع الخطوات.

## 15. دليل المنظمات — البحث والترتيب
- أضيفت أداة بحث مباشرة في دليل المنظمات تدعم الاسم والرمز واسم القائد والوصف، دون حساسية لحالة الأحرف.
- أضيفت خيارات ترتيب حسب السمعة، عدد الأعضاء، المستوى، ورصيد الخزينة، مع ترتيب ثابت بالاسم عند التعادل.
- أضيفت حالة واضحة عند عدم وجود نتائج مطابقة.
- فصل منطق البحث والترتيب في `src/lib/organizationDirectory.ts` وإضافة 4 اختبارات وحدات في `src/tests/organizationDirectory.test.ts`.
- التحقق عبر CI مطلوب قبل اعتبار الدفعة مستقرة.


---

## 10. تحديث الترحيل إلى Supabase — 2026-11-16
- تم تطبيق `nexora_core_schema_v1` و`nexora_fk_indexes_v1` على مشروع `OneState-Trading-DB` داخل schema `nexora` فقط.
- أُنشئت 22 طاولة نطاقية لـ NEXORA: ملفات اللاعبين والبيانات الخاصة، المحافظ والسجل المالي، المخزون والسوق، الشركات والعقارات، المنظمات والخزينة، المطالبات والإنجازات، الإشعارات والأحداث والتدقيق والتشخيص.
- تم تفعيل RLS على الجداول الـ22، والتحقق من عدم وجود أي table grants إلى `anon` أو `authenticated`. لم يتم تفعيل Data API schema exposure أو إضافة سياسات وصول للعميل؛ الحالة مغلقة عمداً إلى أن يُحسم نموذج الهوية ويُنفّذ الخادم الموثوق.
- أضيفت قيود سلامة وفهارس، ومشغلات تمنع تعديل/حذف السجلات المالية وسجلات المطالبات والإنجازات والتدقيق.
- لم تُنقل أي بيانات لاعبين، ولم يتم تغيير جداول OneState في `public`. Firebase Auth وFirestore لا يزالان المصدر الحي للعبة.
- ملاحظات Security Advisor من نوع `rls_enabled_no_policy` على جداول NEXORA متوقعة في هذه المرحلة المغلقة. لا تُعالج بمنح وصول عام. ملاحظات OneState في `public` خارج النطاق ولا يجوز تعديلها.
- سجل التفاصيل: `docs/SUPABASE_SCHEMA_V1.md` و`docs/SUPABASE_SHARED_PROJECT.md`.


## 18. سجل التحقق الأحدث — 2026-11-16
- commit الإصلاح: `ad299d3ffac3e8ee276e6ab122917a74309cd9db` — `test: align market multiplier bounds with pre-rounding calculation`.
- تم تعديل اختبار حدود مضاعف الحدث فقط؛ السعر المرجعي في الاختبار صار يعتمد على السعر بعد عامل العرض وقبل التقريب النهائي. لم يتم تغيير دالة التسعير الإنتاجية.
- أكد مالك المشروع نجاح CI بعد هذا الإصلاح.
- سجل Vercel deployment: `dpl_DbSgaqwkd3oyZkMCSeTTXa8XUqtC`، الحالة `READY`، والفرع `development/nexora-next` والـcommit مطابقان للإصلاح.
- رابط المعاينة: https://nexora-game-git-development-nexora-next-manus24.vercel.app
- أكد مالك المشروع نجاح Workflow نشر قواعد Firestore. يبقى نشر Cloud Functions والتحقق الحي من اللعبة منفصلين عن هذه النتائج.


## 19. تأمين عمليات خزائن الشركات عبر Cloud Functions — 2026-11-16
- نُقلت عمليتا ترقية خزينة الأرباح وتحصيلها من معاملات Firestore التي ينشئها العميل إلى callable Cloud Functions Gen 2: `upgradeCompanyProfitVault` و`collectCompanyRevenueSecure` في `functions/src/index.ts`.
- الخادم يستمد UID من Firebase Auth token ولا يقبل UID من العميل، ويتحقق من ملكية الشركة والرصيد والمواد ومستوى الخزينة، وينفذ تحديث المحفظة والمخزون والشركة والسجل المالي داخل معاملة Firestore ذرّية باستخدام Admin SDK.
- التحصيل يحسب صافي الدخل من بيانات الشركة والمهارات والأحداث النشطة على الخادم، ويحد الرصيد بسعة الخزينة، ويحدّث XP/المستوى/السمعة/التأثير، ثم يصفّر الرصيد ويحدث وقت التحصيل.
- واجهة العميل تستخدم `httpsCallable` فقط لهاتين العمليتين. قواعد Firestore تمنع تحديث حقول الخزينة والتحصيل مباشرة من العميل؛ ما زالت عمليات تطوير الشركة والتوظيف المعتادة ضمن قواعدها السابقة.
- أضيفت `.github/workflows/deploy-company-vault-functions.yml` كمسار نشر يدوي فقط، ومحدد لنشر الدالتين دون بقية الوظائف. لا يبدأ النشر تلقائياً.
- **التحقق**: CI ناجح على commit `d1f18e83d5f75c086863a9980ad3246f7425be0c`، بما يشمل TypeScript، lint قواعد Firestore، Vitest، بناء Vite وبناء Cloud Functions. Vercel كان في حالة BUILDING عند آخر فحص؛ لم يتم اعتماد رابط المعاينة بعد.
- **النشر الحي**: لم يتم بعد نشر الدالتين الجديدتين أو تأكيد نشر قواعد Firestore التي تغلق مسارات العميل. يجب نشر الدالتين أولاً، ثم نشر قواعد Firestore، ثم اختبار الترقية والتحصيل بحساب اختبار. لا تعتبر هذه الوظائف متاحة في الإنتاج قبل هذه الخطوات.
- **الصلاحيات**: Workflow النشر اليدوي يستخدم السر الحالي `FIREBASE_SERVICE_ACCOUNT_NEXORA`. قد يحتاج حساب الخدمة أدوار نشر Cloud Functions Gen 2 وCloud Build وCloud Run وService Account User إضافة إلى Service Usage؛ لا تُشارك مفاتيح الحساب في المحادثة.
- **قرار الدمج**: لا دمج إلى `main` حتى ينجح النشر والاختبار الحي وتتم مراجعة سجلات المعاملات والمواد والأرصدة.


## 20. نقل عمليات خزائن الشركات إلى Vercel + WIF — 2026-11-16
- أضيف endpoint خادمي `api/company-vault.ts` على فرع `development/nexora-next` لتنفيذ الترقية والتحصيل عبر Vercel Functions.
- يتحقق endpoint من Firebase ID token بتوقيع Google ومطابقة `issuer` و`audience`، ويستخرج UID من claim الموقّع فقط؛ لا يقبل UID من جسم الطلب.
- يعتمد الوصول إلى Google Cloud على Vercel OIDC token داخل ترويسة الطلب، ثم Google STS وService Account Impersonation عبر `IdentityPoolClient`؛ لا يوجد مفتاح Service Account JSON ولا أسرار WIF طويلة الأجل في متغيرات Vercel.
- تُنفذ عمليات القراءة والكتابة ضمن Firestore REST read-write transactions على قاعدة البيانات المسماة `ai-studio-74843d9e-8228-49b7-a616-317cadd90bff`. تم نقل حسابات العائد والترقية والمواد والسجل المالي من callable functions إلى endpoint الجديد.
- تم تحديث `src/services/gameService.ts` لاستدعاء `/api/company-vault` بعد الحصول على Firebase ID token.
- **حالة النشر والتحقق:** التغييرات موجودة على فرع التطوير فقط. Vercel deployments قيد الانتظار/البناء عند آخر فحص؛ لم يتم اعتماد READY للـcommit الأخير، ولم يتم إجراء اختبار حي على حساب لاعب. لا تعتبر الخزائن جاهزة للإنتاج بعد.
- **القيود:** لا تغيير على `main`، ولا تغيير على بيانات اللاعبين أو أرصدتهم أو قواعد Firestore المنشورة، ولا تفعيل Billing/Blaze.
