import 'package:flutter/material.dart';
// 👇 هذا الاستيراد كان ناقصاً ويسبب خطأ "Supabase isn't defined"
import 'package:supabase_flutter/supabase_flutter.dart';

class RatingScreen extends StatefulWidget {
  final String orderId;
  const RatingScreen({super.key, required this.orderId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _selectedStars = 5;
  bool _isLoading = false;
  // 👇 نستخدم Map<dynamic, dynamic> لتتوافق مع إرجاع Supabase
  Map<dynamic, dynamic>? _worker;

  @override
  void initState() {
    super.initState();
    _fetchWorkerInfo();
  }

  Future<void> _fetchWorkerInfo() async {
    try {
      final res = await Supabase.instance.client
          .from('orders')
          .select('profiles!orders_worker_id_fkey(full_name, profession, avg_rating)')
          .eq('id', widget.orderId)
          .single();
      
      if (mounted) {
        // 👇 الحل: استخدام .cast() أو التعامل مع dynamic مباشرة
        setState(() => _worker = res['profiles']);
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب بيانات العامل: $e');
    }
  }

  Future<void> _submitRating() async {
    setState(() => _isLoading = true);
    try {
      final order = await Supabase.instance.client
          .from('orders')
          .select('client_id, worker_id')
          .eq('id', widget.orderId)
          .single();

      await Supabase.instance.client.from('ratings').insert({
        'order_id': widget.orderId,
        'client_id': order['client_id'],
        'worker_id': order['worker_id'],
        'stars': _selectedStars,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم التقييم بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل الإرسال: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تقييم الخدمة')),
    body: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_worker != null) ...[
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF1E3A8A),
              child: Text(
                (_worker?['full_name'] as String?)?.substring(0, 1) ?? 'ع',
                style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(_worker?['full_name'] ?? 'العامل', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_worker?['profession'] ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
          ],
          const Text('كيف تقيّم جودة الخدمة؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final val = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = val),
                child: Icon(
                  val <= _selectedStars ? Icons.star : Icons.star_border,
                  color: val <= _selectedStars ? const Color(0xFFF59E0B) : Colors.grey[300],
                  size: 48,
                ),
              );
            }),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('إرسال التقييم', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    ),
  );
}
