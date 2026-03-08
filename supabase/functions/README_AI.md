# تفعيل الذكاء الاصطناعي (Groq) مع Supabase

التطبيق يتصل **فقط بـ Supabase** (يعمل من سوريا بدون VPN). استدعاء نموذج الذكاء يتم من **سيرفر Supabase** عبر Edge Function، لذلك لا يحتاج جهاز المستخدم للوصول إلى Groq مباشرة.

## 1. الحصول على مفتاح Groq (مجاني)

1. ادخل إلى [console.groq.com](https://console.groq.com)
2. سجّل دخولك أو أنشئ حساباً
3. من **API Keys** أنشئ مفتاحاً جديداً (Create API Key)
4. انسخ المفتاح واحتفظ به (يُعرض مرة واحدة)

الطبقة المجانية تتضمن على سبيل المثال:
- آلاف الطلبات يومياً
- نماذج مثل LLaMA 3.3 70B

## 2. نشر Edge Function وإضافة المفتاح

### الطريقة أ: من Supabase Dashboard (بدون CLI)

1. افتح مشروعك في [Supabase Dashboard](https://supabase.com/dashboard) → **Edge Functions**
2. **Create a new function** → الاسم: `ai-chat`
3. الصق محتوى الملف `index.ts` (من مجلد `ai-chat`) في المحرر
4. **Deploy**
5. من **Project Settings** → **Edge Functions** → **Secrets** أضف:
   - الاسم: `GROQ_API_KEY`
   - القيمة: المفتاح الذي نسخته من Groq

### الطريقة ب: باستخدام Supabase CLI

```bash
# تثبيت Supabase CLI إن لم يكن مثبتاً
# npm install -g supabase

# تسجيل الدخول وربط المشروع
supabase login
supabase link --project-ref bsqtumztmqajtowcycfk

# إضافة السر
supabase secrets set GROQ_API_KEY=المفتاح_الذي_نسخته

# نشر الدالة
supabase functions deploy ai-chat
```

## 3. التحقق

بعد النشر، من التطبيق:
- الطالب: من الصفحة الرئيسية اضغط على بطاقة **مساعد الذكاء الاصطناعي** أو من شاشة تسليم الواجب **تلميح من الذكاء الاصطناعي**
- إذا ظهر خطأ مثل "GROQ_API_KEY not set" تأكد من إضافة السر في Supabase كما في الخطوة 2

## نموذج مقترح

- **Groq** (مُستخدم هنا): مجاني، سريع، LLaMA 3.3 70B، يعمل عبر Supabase من سوريا.
- بديل: **DeepSeek** (مجاني أيضاً) — يمكن استبدال الـ URL والمفتاح في الدالة لاستخدامه لاحقاً إن رغبت.
