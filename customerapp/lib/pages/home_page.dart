import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'delivery_page.dart';
import 'login_page.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const DeliveryPage(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons. lock_open_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Delivery',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  Map<String, dynamic>? _latestShipment;
  String? _message;
  String? _userName;

  // Form controller for manual resi input
  final _resiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchShipments();
  }

  @override
  void dispose() {
    _resiController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final name = await ApiClient.getUserName() ?? 'Customer';
    setState(() {
      _userName = name;
    });
  }

  Future<void> _fetchShipments() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final resp = await ApiClient.get('/api/customer/shipments', auth: true);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data'] as List?) ?? [];

        if (list.isEmpty) {
          setState(() {
            _latestShipment = null;
            _message = 'Belum ada paket untuk akun ini.';
          });
        } else {
          setState(() {
            _latestShipment = list.first as Map<String, dynamic>;
          });
        }
      } else if (resp.statusCode == 401) {
        if (! mounted) return;
        await ApiClient.clearToken();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      } else {
        setState(() {
          _message = 'Gagal mengambil data paket.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Tidak bisa terhubung ke server.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLocker() async {
    if (_latestShipment == null) return;

    final resi = _latestShipment!['resi'];
    final courierType = _latestShipment!['courierType'];
    final currentStatus = _latestShipment!['lockerStatus'] ?? 'closed';
    
    // Determine action: if locker is open, close it; if closed, open it
    final isOpening = currentStatus == 'closed';
    final endpoint = isOpening ? '/api/customer/open-locker' : '/api/customer/close-locker';
    final actionText = isOpening ? 'membuka' : 'menutup';

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final resp = await ApiClient.post(
        endpoint,
        {
          'resi': resi,
          'courierType': courierType,
        },
        auth: true,
      );

      final data = jsonDecode(resp.body);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final successMsg = data['message']?.toString() ??
            'Loker berhasil ${isOpening ? "dibuka" : "ditutup"}!';
        
        setState(() {
          _message = successMsg;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh shipment data to get updated locker status
        await _fetchShipments();
      } else {
        final errorMsg = data['error']?.toString() ?? 'Gagal $actionText loker.';
        setState(() {
          _message = errorMsg;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Error koneksi saat $actionText loker.');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat terhubung ke server'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitManualResi() async {
    if (_resiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor resi wajib diisi!')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final resp = await ApiClient.post(
        '/api/customer/manual-resi',
        {
          'resi': _resiController. text.trim(),
        },
        auth: true,
      );

      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        if (! mounted) return;
        ScaffoldMessenger.of(context). showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Resi berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        _resiController.clear();
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Gagal menyimpan resi'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error koneksi ke server'),
          backgroundColor: Colors. red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showManualResiForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Input Resi Manual',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resiController,
              decoration: const InputDecoration(
                labelText: 'Nomor Resi *',
                border: OutlineInputBorder(),
                hintText: 'Contoh: 11002899918893',
              ),
              keyboardType: TextInputType. text,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitManualResi,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (! mounted) return;
    Navigator. of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shipment = _latestShipment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Locker – Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showManualResiForm,
            tooltip: 'Input Resi Manual',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchShipments,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Halo, ${_userName ?? ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (shipment != null) ...[
                _ShipmentInfoCard(shipment: shipment),
                const SizedBox(height: 24),
              ] else ...[
                Text(
                  _message ?? 'Belum ada data paket.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
              ],
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: shipment == null ? null : _toggleLocker,
                    child: AnimatedOpacity(
                      opacity: shipment == null ? 0.5 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _loading
                                ? [Colors.grey.shade300, Colors.grey.shade400]
                                : shipment == null
                                    ? [Colors.grey.shade200, Colors.grey.shade300]
                                    : (shipment['lockerStatus'] == 'open')
                                        ? [Colors.green.shade100, Colors.green.shade200]
                                        : [Colors.white, const Color(0xFFEDEFF5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : Text(
                                (shipment?['lockerStatus'] == 'open') ? 'CLOSE' : 'OPEN',
                                style: TextStyle(
                                  fontSize: 24,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                  color: shipment == null
                                      ? Colors.grey.shade500
                                      : (shipment['lockerStatus'] == 'open')
                                          ? Colors.green.shade700
                                          : Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShipmentInfoCard extends StatelessWidget {
  final Map<String, dynamic> shipment;

  const _ShipmentInfoCard({required this. shipment});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paket Terbaru',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _row('Resi', shipment['resi']),
            _row('Locker', shipment['lockerId']),
            _row('Kurir', shipment['courierType']),
            _row('Status', shipment['status']),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          const Text(': '),
          Expanded(
            child: Text(
              value?. toString() ?? '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}