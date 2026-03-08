/// إعدادات Supabase (تخزين الصور فقط - Firebase يبقى للمصادقة والبيانات)
class SupabaseConfig {
  static const String url = 'https://bsqtumztmqajtowcycfk.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzcXR1bXp0bXFhanRvd2N5Y2ZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5NzQwMjUsImV4cCI6MjA4ODU1MDAyNX0.WT--RyzKVUgI9VGrNEvmJZRY9TZRNsj7eVE8qkwlG5o';

  /// اسم الـ bucket في Supabase Storage (يجب إنشاؤه كـ Public)
  static const String storageBucket = 'images';
}
