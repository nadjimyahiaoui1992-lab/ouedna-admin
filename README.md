# Ouedna Admin — وادنا إدارة

تطبيق الإدارة الرسمي لمنظومة Ouedna. يتيح للمشرفين المصرح لهم مراجعة المعالم والاقتراحات ومحتوى المجتمع، إدارة الموقع والإحداثيات والصور، ومتابعة مؤشرات النشاط المرتبطة بقاعدة Supabase المشتركة.

## الهوية التقنية

| العنصر | القيمة |
|---|---|
| الواجهة | Flutter وMaterial 3 بالعربية RTL |
| حزمة Android | `com.ouedna.admin` |
| البيانات | Supabase مع صلاحيات إدارية بعد تسجيل الدخول |
| التطبيق المرتبط | [Ouedna App](https://ouedna.vercel.app/download) و[Ouedna Web](https://ouedna.vercel.app/) |

## التشغيل والتحقق

يتطلب المشروع Flutter 3.24+ وAndroid SDK 35 وJava 17.

```bash
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

لا تُدرج مفاتيح `service_role` أو بيانات توقيع الإصدار أو ملفات Firebase الخاصة في Git. تُضبط بيانات الوصول المخولة من خلال بيئة الإصدار وSupabase، وتبقى العمليات الإدارية محمية بتسجيل الدخول والسياسات المناسبة.
