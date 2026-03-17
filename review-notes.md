# 📋 Conduit-Deploy Documentation Review

**المراجع:** سيرين  
**التاريخ:** 2026-03-17  
**المشروع:** conduit-deploy  
**النطاق:** جميع ملفات التوثيق (MD + HTML) + السكريبت الرئيسي

---

## 🔴 مشاكل مهمة (High Priority)

### 1. تناقض في وحدة القياس - السكريبت
**الملف:** `conduit-deploy.sh`  
**السطر:** ~550  
**المشكلة:** السكريبت يقول للمستخدم "Enter a number in MB" بس التعليق في الكود يقول "Max: 1024 MB (1 GB)"، والـ validation يسمح بـ 1024 MB كحد أقصى. المشكلة: الـ default في السكريبت هو 100 MB، بس الـ code hardcoded فيه `104857600` bytes (100 MB) ومو واضح للمستخدم إنه يقدر يغيره.

**الاقتراح:**  
- أضف في الـ prompt: `Max: 1024 MB (1 GB). Default: 100 MB.`
- أو خلي الـ default يبين واضح: `[100]` بدل ما يكون فارغ

---

### 2. خلط وحدات في معلومات Media Storage
**الملف:** `conduit-deploy.sh`  
**السطر:** ~560-580  
**المشكلة:** السكريبت يسأل عن "Max media storage in GB" بس المستخدم ممكن يدخل رقم + حرف (مثل "10GB") والسكريبت بيمسحها ويستخدم الرقم بس - مو واضح للمستخدم إنه ما يحتاج يكتب الوحدة.

**الاقتراح:**  
- غير الـ prompt لـ: `Max media storage (enter number in GB only, e.g. 10, 20, 50):`
- أضف تحذير لو المستخدم كتب حروف: "Please enter numbers only (e.g. 10, not 10GB)"

---

### 3. تناقض بين README وملفات MD
**الملف:** `README.md` vs `docs/getting-started.md`  
**السطر:** README line ~90, getting-started line ~30  
**المشكلة:** الـ README يقول "~50MB RAM" بس getting-started يقول "runs on a $5/month VPS" - الأرقام مختلفة شوي (README يقول $6/mo في أماكن ثانية).

**الاقتراح:**  
- وحّد الأسعار في كل المستندات - إما $5/mo أو $6/mo (حالياً DigitalOcean الأرخص هو $6/mo)
- أضف تنويه: "Prices as of [تاريخ]" عشان يكون واضح

---

### 4. معلومات قديمة - VPS Providers
**الملف:** `docs/getting-started.md`  
**السطر:** ~20-30  
**المشكلة:** الجدول يقول Oracle Cloud "Free tier!" بس ما فيه تحذير إنها ARM architecture ومو متوافقة بدون تعديلات (السكريبت tested على x86 Debian 13 فقط).

**الاقتراح:**  
- أضف تحذير واضح: "ARM architecture — requires adjustments, not tested"
- أو امسح Oracle من القائمة عشان ما يتحمس المستخدم ويسويه ويفشل

---

### 5. SRV Record Confusion
**الملف:** `docs/domain-setup.md`  
**السطر:** ~85  
**المشكلة:** الملف يقول "You don't need an SRV record" بس ما يشرح ليش بوضوح - المستخدم العادي ما بيفهم الفرق بين .well-known و SRV.

**الاقتراح:**  
- أضف شرح بسيط: "SRV records are an old method. The script uses .well-known (the modern, recommended way). SRV is only needed if you absolutely cannot serve files on your root domain — which is very rare."

---

### 6. تناقض في Media Backup
**الملف:** `conduit-deploy.sh` + `docs/after-install.md`  
**السطر:** السكريبت line ~1450, after-install line ~60  
**المشكلة:** السكريبت يسأل "Include media files in backup?" بس الـ docs ما تذكر هالخيار - المستخدم بيفاجأ لما يشوف الخيار بدون توضيح مسبق.

**الاقتراح:**  
- أضف في after-install.md قسم: "Backup Options — with or without media"
- اشرح الفرق: With media = full backup, Without = smaller, accounts/messages saved but no uploaded files

---

## 🟡 مشاكل متوسطة (Medium Priority)

### 7. روابط داخلية مكسورة
**الملف:** `docs/walkthrough.html`  
**السطر:** ~100  
**المشكلة:** فيه رابط لـ `docs/backup-restore.md` بس الملف ما موجود - المعلومات موجودة في `walkthrough.html` بس.

**الاقتراح:**  
- امسح الرابط أو غيره لـ: `#backup` (anchor في نفس الصفحة)

---

### 8. مصطلحات مو واضحة
**الملف:** `docs/advanced/turn-calls.md`  
**السطر:** ~40  
**المشكلة:** الملف يقول "TURNS (TLS) not recommended" بس ما يشرح ليش بشكل مفهوم للمبتدئ - يقول "performance cost" بس ما يوضح كم التأثير.

**الاقتراح:**  
- أضف مثال: "TURNS forces all call traffic through TCP (slower) even when UDP works fine — this can add 100-200ms latency"

---

### 9. أخطاء إملائية
**الملف:** `docs/installation.md`  
**السطر:** ~120  
**المشكلة:** "Debain" بدل "Debian" (typo)

**الاقتراح:** صحح لـ "Debian"

---

### 10. تناقض في الـ HTML vs MD - Admin Room
**الملف:** `docs/admin-room.md` vs `docs/admin.html`  
**السطر:** MD line ~80, HTML line ~120  
**المشكلة:** الـ MD يقول `reset-password` يستقبل `<user_id> <password>` بس الـ HTML يقول إنه يولد رقم سري عشوائي (مو يستقبل واحد من المستخدم).

**الاقتراح:**  
- راجع الـ Conduit API - إذا `reset-password` يولد رقم سري عشوائي، صحح الـ MD
- إذا يستقبل password من المستخدم، صحح الـ HTML

---

### 11. معلومات ناقصة - Firewall Rules
**الملف:** `docs/architecture.html`  
**السطر:** ~150  
**المشكلة:** الملف يذكر UFW ports بس ما يذكر الـ iptables UDP redirect (443 → 5349) اللي السكريبت يسويه.

**الاقتراح:**  
- أضف في Port Table: "UDP 443 (redirected to 5349 via iptables)"

---

### 12. تناقض في Password Recovery
**الملف:** `docs/admin-room.md` vs السكريبت  
**السطر:** MD line ~100, السكريبت line ~2200  
**المشكلة:** الـ MD يقول إن `reset-password` يولد رقم سري عشوائي، بس السكريبت في بعض الأماكن يستخدم `<password>` parameter - مو واضح أي الاثنين صح.

**الاقتراح:**  
- اختبر الـ command الفعلي في Conduit وتأكد من الـ syntax الصحيح
- وحّد الكتابة في كل الملفات

---

### 13. ملف setup.sh مو موثق
**الملف:** `setup.sh`  
**المشكلة:** فيه سكريبت `setup.sh` في الـ root بس مو مذكور في أي documentation - مو واضح وش وظيفته.

**الاقتراح:**  
- إما تحذفه إذا مو مستخدم
- أو أضف شرح في README: "setup.sh is for [الغرض]"

---

## 🟢 تحسينات (Improvements)

### 14. مو واضح للمبتدئ - DNS Propagation
**الملف:** `docs/domain-setup.md`  
**السطر:** ~60  
**المشكلة:** الملف يقول "wait a few minutes" بس ما يحدد كم - المبتدئ بيستعجل ويقول "ما اشتغل".

**الاقتراح:**  
- غير لـ: "DNS propagation takes 5-30 minutes. Use dnschecker.org to verify."

---

### 15. أمثلة أكثر وضوحاً
**الملف:** `docs/faq.md`  
**السطر:** ~80  
**المشكلة:** الـ FAQ يقول "How many users?" بس ما فيه أمثلة واقعية - مثلاً كم رسالة في اليوم، كم غرفة، إلخ.

**الاقتراح:**  
- أضف مثال: "Family of 5 people, 100 messages/day → 1GB RAM is plenty"

---

### 16. تحسين الـ Error Messages
**الملف:** `conduit-deploy.sh`  
**السطر:** ~400  
**المشكلة:** لما DNS validation يفشل، السكريبت يقول "does not resolve" بس ما يعطي خطوات واضحة للمستخدم يسويها.

**الاقتراح:**  
- أضف: "Run 'dig your-domain.com' to check if DNS is ready. If it returns NXDOMAIN, your DNS record is not set up yet."

---

### 17. أشياء ناقصة - Backup Location
**الملف:** `README.md`  
**السطر:** ~200  
**المشكلة:** الـ README يقول "Backups are stored separately" بس ما يقول وين بالضبط - المستخدم لازم يدور.

**الاقتراح:**  
- أضف: "Backups are stored at `/opt/conduit-backups/` (separate from `/opt/conduit/`)"

---

### 18. تحسين الـ Comparison Table
**الملف:** `docs/getting-started.md`  
**السطر:** ~50  
**المشكلة:** الجدول يقارن Matrix مع WhatsApp/Telegram بس ما يذكر Discord (شعبي في المجموعات).

**الاقتراح:**  
- أضف عمود Discord في الجدول

---

### 19. وضوح أكثر - Subdomain Mode
**الملف:** `docs/domain-setup.md`  
**السطر:** ~100  
**المشكلة:** الملف يقول "Subdomain mode is easier" بس ما يحذر إن الـ username بيكون أطول - المستخدم ممكن يندم بعدين.

**الاقتراح:**  
- أضف تحذير واضح: "⚠️ Your username will be `@user:chat.example.com` — longer but simpler setup"

---

### 20. تحسين الـ Health Check Output
**الملف:** `conduit-deploy.sh`  
**السطر:** ~1100  
**المشكلة:** لما Health Check يقول "Services need restart", ما يقول كيف المستخدم يسويها.

**الاقتراح:**  
- أضف: "Run: sudo systemctl restart [service-name]"

---

### 21. ملف TODO.md مو مربوط بالـ docs
**الملف:** `TODO.md`  
**المشكلة:** الـ TODO فيه أفكار حلوة بس ما في رابط ليه من الـ docs الرئيسية - المستخدم العادي ما بيعرف عنه.

**الاقتراح:**  
- أضف رابط في README تحت قسم "Roadmap": [See full roadmap](TODO.md)

---

### 22. تناقض بسيط - Default Values
**الملف:** السكريبت  
**السطر:** ~570  
**المشكلة:** السكريبت يحسب defaults بناءً على disk size بس ما يشرح الحسبة للمستخدم - ممكن يتفاجأ لما يشوف 50GB suggested.

**الاقتراح:**  
- أضف توضيح: "Suggested based on your available disk space (50% of free space)"

---

### 23. وضوح أكثر - .well-known Option B
**الملف:** `docs/installation.md` + `conduit-deploy.sh`  
**السطر:** MD line ~90, السكريبت line ~630  
**المشكلة:** Option B (existing website) مو fully tested بس السكريبت ما يحذر بشكل واضح - المستخدم ممكن يختاره ويفشل.

**الاقتراح:**  
- أضف في السكريبت: "⚠️ Option B has not been fully tested. Choose Option A if possible."

---

### 24. تحسين الـ Backup Prompt
**الملف:** `conduit-deploy.sh`  
**السطر:** ~1450  
**المشكلة:** لما السكريبت يسأل "Include media files?", ما يوضح كم الفرق في الحجم - المستخدم ما يعرف إذا يستحق أو لا.

**الاقتراح:**  
- أضف: "Media size: [XX MB]. Without media, backup will be ~50% smaller."

---

### 25. تحذير مهم مفقود - Reinstall
**الملف:** `conduit-deploy.sh`  
**السطر:** ~400  
**المشكلة:** لما المستخدم يختار Reinstall, السكريبت يسوي auto-backup بس ما يقول للمستخدم وين راح يحفظها - ممكن يضيع.

**الاقتراح:**  
- أضف: "Auto-backup saved to: /opt/conduit-backups/conduit-backup-[timestamp].tar.gz"

---

### 26. تحسين الـ Error Handling - Port Conflicts
**الملف:** `conduit-deploy.sh`  
**السطر:** ~700  
**المشكلة:** لما يلاقي port conflict، السكريبت يقول "Port XX is in use by: unknown" - مو مفيد.

**الاقتراح:**  
- حسن الـ detection: استخدم `lsof -i :PORT` بدل `ss` كـ fallback

---

### 27. تناقض بسيط - IPv6 في الـ docs
**الملف:** `docs/domain-setup.md`  
**السطر:** ~70  
**المشكلة:** الملف يقول "optional but recommended" بس ما يشرح الفايدة - المبتدئ ما بيعرف ليش يحتاجها.

**الاقتراح:**  
- أضف: "IPv6 allows clients on modern networks to connect faster. If your VPS has IPv6, enable it."

---

### 28. وضوح أكثر - Disk Space Check
**الملف:** `conduit-deploy.sh`  
**السطر:** ~1300  
**المشكلة:** السكريبت يقول "Not enough disk space" بس ما يقول كم محتاج بالضبط.

**الاقتراح:**  
- غير لـ: "Need at least [XX]GB free space. You have [YY]GB."

---

### 29. معلومات ناقصة - Update Process
**الملف:** `docs/faq.md`  
**السطر:** ~150  
**المشكلة:** الـ FAQ يقول "update containers" بس ما يشرح وش بيحصل للـ data - المستخدم بيخاف يخسر الرسائل.

**الاقتراح:**  
- أضف: "Updates only replace the software — your data (messages, accounts) is safe in Docker volumes"

---

### 30. تحسين الـ Success Messages
**الملف:** `conduit-deploy.sh`  
**السطر:** ~900  
**المشكلة:** لما التثبيت ينتهي، السكريبت يقول "Installation Complete!" بس ما يعطي next step واضح.

**الاقتراح:**  
- أضف: "Next: Run Health Check (option 3) to verify everything is working"

---

## ملخص الأولويات

| الأولوية | العدد | الأمثلة |
|---------|-------|---------|
| 🔴 مهم | 6 | خلط وحدات، تناقضات بين الملفات، معلومات قديمة |
| 🟡 متوسط | 7 | روابط مكسورة، مصطلحات مو واضحة، أخطاء إملائية |
| 🟢 تحسين | 17 | وضوح أكثر، أمثلة، error messages أفضل |

**المجموع:** 30 ملاحظة

---

## توصيات عامة

1. **وحّد الأرقام والوحدات** - $5 vs $6, MB vs GB, إلخ - لازم تكون consistent
2. **أضف أمثلة واقعية** - المبتدئ يحتاج يشوف أمثلة عشان يفهم
3. **حسّن Error Messages** - خلي كل error يقول وش المشكلة + كيف الحل
4. **راجع الـ HTML vs MD** - فيه تناقضات بسيطة بينهم
5. **اختبر Option B** (.well-known external) - أو امسحها إذا مو متأكد منها
6. **أضف Changelog** - عشان المستخدم يعرف وش تغير بين النسخ

---

**✅ المراجعة كاملة!**  
كل الملفات متراجعة ومسجلة. الملاحظات جاهزة للتنفيذ.
