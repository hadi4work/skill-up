# Firestore Security Rules - قواعد مفتوحة (للتطوير فقط)

⚠️ **تحذير**: هذه القواعد تسمح لجميع المستخدمين بالقراءة والكتابة بدون قيود. استخدمها فقط للتطوير والاختبار، وليس للإنتاج!

## Firestore Rules

انسخ هذه القواعد إلى Firebase Console > Firestore Database > Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // السماح لجميع المستخدمين بالقراءة والكتابة بدون قيود
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Firebase Storage Rules

انسخ هذه القواعد إلى Firebase Console > Storage > Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // السماح لجميع المستخدمين بالقراءة والكتابة بدون قيود
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## كيفية تطبيق القواعد:

### Firestore Rules:
1. افتح [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك `smartapp-a308b`
3. اذهب إلى **Firestore Database** > **Rules**
4. انسخ قواعد Firestore أعلاه والصقها
5. اضغط **Publish**

### Storage Rules:
1. في نفس Firebase Console
2. اذهب إلى **Storage** > **Rules**
3. انسخ قواعد Storage أعلاه والصقها
4. اضغط **Publish**

## ملاحظات:

- ✅ هذه القواعد تسمح لجميع المستخدمين المسجلين بالقراءة والكتابة
- ✅ لا توجد قيود على أي collection أو document
- ✅ لا توجد قيود على أي file في Storage
- ⚠️ **غير آمنة للإنتاج** - استخدمها فقط للتطوير والاختبار
- ⚠️ يجب تغييرها لاحقاً بقواعد أكثر أماناً للإنتاج

## للاستخدام في الإنتاج:

عندما تكون جاهزاً للإنتاج، يجب استبدال هذه القواعد بقواعد أكثر أماناً تحدد:
- من يمكنه القراءة
- من يمكنه الكتابة
- ما هي البيانات المسموح بها
- التحقق من صحة البيانات
