import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String _referralCode = '---';
  int _points = 0;
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    // جلب بيانات المستخدم
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('referral_code, points')
        .eq('id', userId)
        .single();
    
    // جلب سجل المكافآت
    final rewards = await Supabase.instance.client
        .from('referral_rewards')
        .select('points_awarded, reason, created_at, profiles!referrer_id(display_name)')
        .eq('referred_id', userId)
        .order('created_at', ascending: false)
        .limit(10);

    if (mounted) {
      setState(() {
        _referralCode = profile['referral_code'] ?? '---';
        _points = profile['points'] ?? 0;
        _rewards = List<Map<String, dynamic>>.from(rewards);
        _isLoading = false;
      });
    }
  }

  void _copyCode() {
    // يمكن إضافة حزمة clipboard هنا
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ تم نسخ الكود: $_referralCode')),
    );
  }

  void _shareCode() {
    // يمكن إضافة حزمة share هنا
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📤 شارك الكود مع أصدقائك!')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('كود الإحالة والمكافآت')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بطاقة الكود
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('كود الإحالة الخاص بك', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _referralCode,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('نسخ'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _shareCode,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('مشاركة'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // بطاقة النقاط
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFF59E0B), size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('رصيد النقاط', style: TextStyle(color: Colors.grey)),
                          Text('$_points نقطة', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // شرح النظام
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🎁 كيف تعمل المكافآت؟', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('• سجل صديقك باستخدام كودك: +10 نقطة لك'),
                      const Text('• أكمل صديقك أول طلب: +20 نقطة لك'),
                      const Text('• استخدم نقاطك لخصومات على خدمات مستقبلية'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // سجل المكافآت
                if (_rewards.isNotEmpty) ...[
                  const Text('📜 سجل المكافآت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rewards.length,
                    itemBuilder: (context, i) {
                      final r = _rewards[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: const Icon(Icons.add, color: Colors.green),
                          ),
                          title: Text('+${r['points_awarded']} نقطة'),
                          subtitle: Text(r['reason'] ?? 'مكافأة إحالة'),
                          trailing: Text(
                            '${DateTime.parse(r['created_at']).day}/${DateTime.parse(r['created_at']).month}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('لا توجد مكافآت بعد', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ],
              ],
            ),
          ),
  );
}
