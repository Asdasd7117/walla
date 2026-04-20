import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class ReferralInputScreen extends StatefulWidget {
  const ReferralInputScreen({super.key});
  @override
  State<ReferralInputScreen> createState() => _ReferralInputScreenState();
}

class _ReferralInputScreenState extends State<ReferralInputScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _skip();
      return;
    }
    if (code.length != 8 || !RegExp(r'^\d{8}$').hasMatch(code)) {
      setState(() => _error = 'كود الإحالة يجب أن يكون 8 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // البحث عن صاحب الكود
      final referrer = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('referral_code', code)
          .neq('id', userId)  // لا يمكن إحالة النفس
          .maybeSingle();

      if (referrer != null) {
        // تحديث المستخدم الحالي بأنه تم إحالته
        await Supabase.instance.client
            .from('profiles')
            .update({'referred_by': referrer['id']})
            .eq('id', userId);
      } else {
        setState(() => _error = 'كود الإحالة غير صحيح');
        return;
      }
    } catch (e) {
      setState(() => _error = 'حدث خطأ: $e');
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    _navigateToHome();
  }

  void _skip() {
    // تخطي إدخال الكود (اختياري)
    _navigateToHome();
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('كود الإحالة'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _skip,
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 64, color: Theme.of(context).primaryColor),
          const SizedBox(height: 24),
          const Text(
            'أدخل كود إحالة صديقك',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'احصل أنت وصديقك على 10 نقاط مكافأة',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '00000000',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تأكيد الكود', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _skip,
            child: const Text('تخطي الآن', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    ),
  );
}
