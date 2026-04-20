import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'orders_screen.dart';
import 'referral_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _city;
  String? _selectedServiceId;
  final _phoneController = TextEditingController();
  final _descController = TextEditingController();
  List<Map<String, dynamic>> _services = [];
  Position? _position;
  String? _displayName;
  int _userPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profileRes = await Supabase.instance.client
        .from('profiles')
        .select('display_name, points')
        .eq('id', user.id)
        .single();
    
    setState(() {
      _displayName = profileRes['display_name'] ?? 'عميل';
      _userPoints = profileRes['points'] ?? 0;
    });
    
    final servicesRes = await Supabase.instance.client
        .from('services')
        .select('id, name, description, base_price');
    setState(() => _services = List<Map<String, dynamic>>.from(servicesRes));
  }

  Future<void> _getLocation() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تفعيل الموقع لإرسال الطلب')),
        );
      }
      return;
    }
    setState(() => _position = await Geolocator.getCurrentPosition());
  }

  void _selectCity() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر المدينة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _cityOption('صنعاء'),
            _cityOption('عدن'),
          ],
        ),
      ),
    );
  }

  Widget _cityOption(String cityName) => ListTile(
    leading: const Icon(Icons.location_city, color: Color(0xFF1E3A8A)),
    title: Text(cityName),
    onTap: () {
      setState(() => _city = cityName);
      Navigator.pop(context);
    },
  );

  Future<void> _submitOrder() async {
    // التحقق من المدخلات
    if (_city == null) {
      _showError('يرجى اختيار المدينة أولاً');
      return;
    }
    if (_selectedServiceId == null) {
      _showError('يرجى اختيار الخدمة');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError('يرجى إدخال رقم الهاتف');
      return;
    }
    if (!RegExp(r'^05[0-9]{8}$').hasMatch(_phoneController.text.trim())) {
      _showError('رقم الهاتف غير صحيح (يجب أن يبدأ بـ 05 ويحتوي 10 أرقام)');
      return;
    }
    if (_descController.text.trim().isEmpty) {
      _showError('يرجى وصف المشكلة المطلوبة');
      return;
    }
    if (_position == null) {
      _showError('يرجى تحديد موقعك');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('orders').insert({
        'client_id': user.id,
        'service_id': _selectedServiceId,
        'city': _city,
        'client_phone': _phoneController.text.trim(),
        'client_description': _descController.text.trim(),
        'client_lat': _position!.latitude,
        'client_lng': _position!.longitude,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إرسال الطلب بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
      }
    } catch (e) {
      _showError('فشل إرسال الطلب: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changeName() async {
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('name_last_changed_at')
        .eq('id', Supabase.instance.client.auth.currentUser!.id)
        .single();
    
    final lastChanged = DateTime.parse(profile['name_last_changed_at']);
    if (DateTime.now().difference(lastChanged).inDays < 30) {
      _showError('يمكنك تغيير الاسم مرة واحدة كل 30 يومًا');
      return;
    }
    
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير الاسم'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.trim().isNotEmpty) {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'display_name': newName.trim(),
            'name_last_changed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', Supabase.instance.client.auth.currentUser!.id);
      setState(() => _displayName = newName.trim());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: Builder(builder: (context) => 
        IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())
      ),
      title: const Text('خدمات يمن اونلاين', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
          icon: const Icon(Icons.list_alt),
          label: const Text('طلباتي'),
        ),
      ],
    ),
    drawer: Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 30, backgroundColor: Colors.white, 
                      child: Icon(Icons.person, color: Color(0xFF1E3A8A), size: 30)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 👈 النقاط تظهر فوق الاسم
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '⭐ $_userPoints نقطة',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_displayName ?? 'عميل', 
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.edit), title: const Text('تغيير الاسم'), onTap: _changeName),
          
          // 👈 رابط الإحالة الجديد
          ListTile(
            leading: const Icon(Icons.card_giftcard, color: Color(0xFFF59E0B)),
            title: const Text('كود الإحالة والمكافآت'),
            onTap: () {
              Navigator.pop(context); // إغلاق القائمة أولاً
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen()));
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.headset_mic, color: Colors.green),
            title: const Text('خدمة العملاء (واتساب)'),
            onTap: () => launchUrl(Uri.parse('https://wa.me/9677XXXXXXXXX')),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
              }
            },
          ),
        ],
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // المدينة
                const Text('📍 المدينة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectCity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _city ?? 'اختر المدينة',
                            style: TextStyle(
                              fontSize: 16,
                              color: _city == null ? Colors.grey : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // الخدمة
                const Text('🛠️ الخدمة المطلوبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  hint: const Text('اختر الخدمة'),
                  value: _selectedServiceId,
                  items: _services.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name']))).toList(),
                  onChanged: (v) => setState(() => _selectedServiceId = v),
                ),
                const SizedBox(height: 16),

                // هاتف العميل
                const Text('📱 رقم هاتفك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '05XXXXXXXX',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),

                // تفاصيل الخدمة
                const Text('📝 تفاصيل المشكلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'اشرح المشكلة بالتفصيل (مثال: تسريب مياه في المطبخ، يحتاج سباك)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // الموقع
                ElevatedButton.icon(
                  onPressed: _getLocation,
                  icon: Icon(_position == null ? Icons.location_on : Icons.check_circle, color: Colors.white),
                  label: Text(_position == null ? 'تحديد موقعي الحالي' : '✅ تم تحديد الموقع'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _position == null ? const Color(0xFF3B82F6) : Colors.green,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // زر الإرسال
                ElevatedButton(
                  onPressed: _submitOrder,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('🚀 إرسال الطلب', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
