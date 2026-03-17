# Skipped Review Notes

## ملاحظات تم تخطيها مع الأسباب

### 7. روابط داخلية مكسورة
**السبب:** ما لقيت رابط مكسور لـ `backup-restore.md` في `docs/walkthrough.html` (line ~100). بحثت بـ grep وما طلع شي. الـ backup documentation موجودة inline في الملف نفسه.

**حالة:** لا يحتاج إصلاح - الملاحظة مو دقيقة.

---

### 9. أخطاء إملائية ("Debain")
**السبب:** بحثت عن "Debain" في كل الملفات (grep -rn) وما لقيت أي typo. يمكن تم إصلاحه قبل.

**حالة:** لا يحتاج إصلاح - غير موجود.

---

### 17. أشياء ناقصة - Backup Location
**السبب:** المعلومات موجودة فعلاً في README line 153: "Backups are stored separately at `/opt/conduit-backups/`"

**حالة:** لا يحتاج إصلاح - موجود بالفعل.

---

### 18. تحسين الـ Comparison Table
**السبب:** ما لقيت comparison table بين Matrix و WhatsApp/Telegram في docs/getting-started.md. الملاحظة تتكلم عن جدول مقارنة مو موجود.

**حالة:** لا يحتاج إصلاح - الجدول غير موجود أصلاً.

---

### 21. ملف TODO.md مو مربوط بالـ docs
**السبب:** الرابط موجود فعلاً في README line 52: `[Roadmap](TODO.md)`

**حالة:** لا يحتاج إصلاح - موجود بالفعل.

---

### 26. تحسين الـ Error Handling - Port Conflicts
**السبب:** الكود الحالي يستخدم `ss` و `netstat` بشكل جيد، ويحاول يطلع اسم البرنامج اللي مستخدم الـ port. الاقتراح كان استخدام `lsof` كـ fallback بس `ss` و `netstat` كافيين ومثبتين افتراضياً على Debian.

**حالة:** التنفيذ الحالي كافٍ - لا يحتاج تعديل.

---

### 28. وضوح أكثر - Disk Space Check
**السبب:** الرسالة الحالية واضحة وتحدد الأرقام بدقة (line 1698-1699 in conduit-deploy.sh):
```
Estimated backup size: ~XXmb
Available disk space:  YYmb
```

**حالة:** الرسالة واضحة بالفعل - لا يحتاج تعديل.

---
