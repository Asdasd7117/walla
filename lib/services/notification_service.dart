import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // طلب الصلاحيات
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    
    // الحصول على التوكن وحفظه
    final token = await _messaging.getToken();
    if (token != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', Supabase.instance.client.auth.currentUser?.id);
    }

    // استقبال الإشعارات في المقدمة
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('🔔 إشعار: ${msg.notification?.title}');
      // يمكن إضافة flutter_local_notifications هنا لعرض إشعار مخصص
    });

    // عند النقر على إشعار
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('🖱️ نقر: ${msg.data}');
      // يمكن التنقل لصفحة الطلب إذا كان فيها order_id
    });

    // التحقق من فتح التطبيق عبر إشعار
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('🚀 فتح من إشعار: ${initial.data}');
    }
  }
}
