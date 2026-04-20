import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'referral_input_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      
      final googleAuth = await googleUser.authentication;
      final authResponse = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      
      final user = authResponse.user;
      if (user == null) return;

      // التحقق مما إذا كان الملف الشخصي موجوداً
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // إنشاء ملف شخصي جديد مع كود إحالة تلقائي
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'display_name': user.userMetadata?['full_name'] ?? googleUser.displayName,
          'phone': user.userMetadata?['phone'],
          'role': 'client',
          'referral_code': _generateReferralCode(),
        });
      }

      if (context.mounted) {
        // الانتقال لشاشة إدخال كود الإحالة (اختياري)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReferralInputScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تسجيل الدخول: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // توليد كود إحالة عشوائي 8 أرقام
  String _generateReferralCode() {
    return (10000000 + (DateTime.now().millisecondsSinceEpoch % 90000000)).toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)]),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'خدمات اونلاين',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Text('تسجيل أو دخول', style: TextStyle(fontSize: 24, color: Color(0xFF0F172A))),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => _signInWithGoogle(context),
                    icon: const Icon(Icons.login),
                    label: const Text('الدخول عبر حساب Google'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'بالتسجيل، توافق على شروط الاستخدام وسياسة الخصوصية',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}
