import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'rating_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  RealtimeChannel? _channel;
  String _userRole = 'client';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadOrders();
  }

  Future<void> _loadUserRole() async {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', Supabase.instance.client.auth.currentUser!.id)
        .single();
    setState(() => _userRole = res['role']);
  }

  Future<void> _loadOrders() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    final query = Supabase.instance.client.from('orders').select('''
      id, status, created_at, city, client_phone, client_description, client_lat, client_lng,
      services(name, base_price),
      profiles!orders_client_id_fkey(display_name, phone),
      profiles!orders_worker_id_fkey(display_name, phone, profession, avg_rating)
    ''');

    final List<Map<String, dynamic>> res;
    if (_userRole == 'worker') {
      // العامل يرى الطلبات المخصصة له + الطلبات المعلقة في مدينته
      res = await query.or('worker_id.eq.$userId,and(status.eq.pending,city.eq.${Supabase.instance.client.from('profiles').select('city').eq('id', userId).single().then((v) => v['city'])})');
    } else {
      // العميل يرى طلباته فقط
      res = await query.eq('client_id', userId).order('created_at', ascending: false);
    }
    
    if (mounted) setState(() => _orders = List<Map<String, dynamic>>.from(res));

    // تحديث لحظي
    _channel = Supabase.instance.client.channel('orders_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (_) => _loadOrders(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // للعامل: قبول/بدء/إنهاء الطلب
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await Supabase.instance.client.from('orders').update({'status': newStatus}).eq('id', orderId);
    _loadOrders();
  }

  // للعامل: الاتصال بالعميل
  Future<void> _callClient(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_userRole == 'worker' ? 'طلباتي (كعامل)' : 'طلباتي'),
      actions: _userRole == 'worker' ? [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadOrders,
        ),
      ] : null,
    ),
    body: _orders.isEmpty 
        ? Center(child: Text(_userRole == 'worker' ? 'لا توجد طلبات معلقة في منطقتك' : 'لا توجد طلبات بعد'))
        : ListView.builder(
            itemCount: _orders.length,
            itemBuilder: (context, i) {
              final o = _orders[i];
              final isWorker = _userRole == 'worker';
              final client = o['profiles!orders_client_id_fkey'];
              final worker = o['profiles!orders_worker_id_fkey'];
              final service = o['services'];
              final status = o['status'];
              
              final statusConfig = {
                'pending': {'color': Colors.orange, 'text': 'قيد الانتظار', 'icon': Icons.pending},
                'accepted': {'color': Colors.blue, 'text': 'تم القبول', 'icon': Icons.check_circle},
                'in_progress': {'color': Colors.purple, 'text': 'قيد التنفيذ', 'icon': Icons.build},
                'completed': {'color': Colors.green, 'text': 'تم التنفيذ', 'icon': Icons.done},
                'cancelled': {'color': Colors.red, 'text': 'ملغى', 'icon': Icons.cancel},
              }[status]!;

              return Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // رأس البطاقة: الخدمة + الحالة
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🛠️ ${service['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (service['base_price'] != null)
                                  Text('السعر التقريبي: ${service['base_price']} ريال', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusConfig['color'] as Color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusConfig['icon'] as IconData, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(statusConfig['text'] as String, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // 👈 للعامل: تفاصيل العميل (هاتف + وصف + موقع)
                      if (isWorker) ...[
                        const Text('👤 بيانات العميل', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text('هاتف: ${o['client_phone']}')),
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () => _callClient(o['client_phone']),
                            ),
                          ],
                        ),
                        if (o['client_description'] != null) ...[
                          const SizedBox(height: 4),
                          Text('📝 ${o['client_description']}'),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('المدينة: ${o['city']}'),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => launchUrl(Uri.parse(
                                'https://maps.google.com/?q=${o['client_lat']},${o['client_lng']}',
                              )),
                              icon: const Icon(Icons.map, size: 18),
                              label: const Text('عرض على الخريطة'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],

                      // للعميل: بيانات العامل
                      if (!isWorker && worker != null) ...[
                        const Text('👷 بيانات العامل', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('الاسم: ${worker['display_name']}'),
                        Text('المهنة: ${worker['profession']}'),
                        Text('الهاتف: ${worker['phone']}'),
                        if (worker['avg_rating'] != null)
                          Text('التقييم: ${'⭐' * (worker['avg_rating'] as double).round()}', style: const TextStyle(color: Colors.amber)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => launchUrl(Uri.parse('tel:${worker['phone']}')),
                              child: const Text('اتصال بالعامل'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],

                      // أزرار التحكم (للعامل فقط)
                      if (isWorker && status == 'pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateOrderStatus(o['id'], 'accepted'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('✅ قبول الطلب'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _updateOrderStatus(o['id'], 'cancelled'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('❌ رفض'),
                              ),
                            ),
                          ],
                        ),
                      ] else if (isWorker && status == 'accepted') ...[
                        ElevatedButton(
                          onPressed: () => _updateOrderStatus(o['id'], 'in_progress'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                          child: const Text('🔧 بدء التنفيذ'),
                        ),
                      ] else if (isWorker && status == 'in_progress') ...[
                        ElevatedButton(
                          onPressed: () => _updateOrderStatus(o['id'], 'completed'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('✨ إنهاء الخدمة'),
                        ),
                      ],

                      // زر التقييم (للعميل بعد اكتمال الخدمة)
                      if (!isWorker && status == 'completed') ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RatingScreen(orderId: o['id'])),
                          ),
                          icon: const Icon(Icons.star_rate, color: Colors.amber),
                          label: const Text('⭐ تقييم العامل'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
