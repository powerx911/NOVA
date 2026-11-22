# تهيئة أول حساب Owner

لا تُرسل كلمة المرور أو مفاتيح Supabase داخل المحادثة أو المستودع. أنشئ الحساب من لوحة Supabase ثم اربطه بدور Owner من SQL Editor.

1. من Supabase Dashboard للمشروع NOVA، افتح Authentication → Users وأنشئ مستخدمًا بالبريد الذي تملكه وكلمة مرور قوية وفريدة. لا تستخدم حساب لاعب Firebase.
2. افتح SQL Editor ونفّذ الاستعلام التالي بعد استبدال `owner@example.com` بالبريد نفسه. يجب أن يُرجع صفًا واحدًا:

```sql
insert into public.admin_accounts (user_id, role, enabled)
select id, 'owner', true
from auth.users
where lower(email) = lower('owner@example.com')
on conflict (user_id) do nothing
returning user_id, role, enabled;
```

3. إذا لم يُرجع صفًا، تحقق أن مستخدم Auth موجود وأنه غير مرتبط مسبقًا. لا تمنح دور Owner لحساب غير مملوك لك.
4. بعد نشر دالة `admin-center` والواجهة، سجّل الدخول من صفحة مركز الإدارة. أنشئ حسابات Admin من نموذج Owner داخل الموقع فقط.

الجدول لا يخزّن كلمات المرور. دالة الخادم تتحقق من الدور قبل إنشاء Admin، ولا يُسمح بإنشاء Owner من الواجهة. قيد قاعدة البيانات يمنع أكثر من Owner مفعّل واحد.
