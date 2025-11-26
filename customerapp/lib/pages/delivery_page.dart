import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'tracking_detail_page.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({Key? key}) : super(key: key);

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _shipments = [];

  @override
  void initState() {
    super.initState();
    _fetchShipments();
  }

  Future<void> _fetchShipments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) ambil list shipment milik user yang login
      final resp = await ApiClient.get('/api/customer/shipments', auth: true);

      if (resp.statusCode != 200) {
        setState(() {
          _error = 'Gagal load shipments (${resp.statusCode})';
        });
        return;
      }

      final data = jsonDecode(resp.body);
      final list = (data['data'] as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      // 2) untuk tiap resi, panggil tracking Binderbyte via backend
      for (final s in list) {
        final resi = (s['resi'] ?? '').toString();
        final courierType = (s['courierType'] ?? '').toString();

        if (resi.isEmpty || courierType.isEmpty) continue;

        try {
          final trackResp = await ApiClient.get(
            '/api/customer/track/$resi',
            query: {'courier': courierType},
            auth: true,
          );

          if (trackResp.statusCode == 200) {
            final tData = jsonDecode(trackResp.body);
            final summary = tData['binderbyte']?['data']?['summary'];
            if (summary != null) {
              s['trackingStatus'] =
                  (summary['status'] ?? '').toString(); // DELIVERED / HILANG / ON PROCESS ...
            }
          }
        } catch (_) {
          // kalau tracking error, abaikan saja (tetap bisa tampil memakai status internal)
        }
      }

      setState(() {
        _shipments = list;
      });
    } catch (e) {
      setState(() {
        _error = 'Error koneksi: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Tentukan label & warna berdasarkan status Binderbyte (utama)
  /// lalu fallback ke status internal smart locker.
  ({String label, Color bg, Color dot, Color truck}) _statusVisual(
      Map<String, dynamic> s) {
    final external = (s['trackingStatus'] ?? '').toString().toUpperCase();
    final internal = (s['status'] ?? '').toString(); // pending_locker, completed, dll.

    // default
    String label = 'Dalam proses';
    Color bg = const Color(0xFFE0ECFF);
    Color dot = const Color(0xFF2563EB);
    Color truck = const Color(0xFF2563EB);

    if (external.contains('DELIVERED')) {
      label = 'Diterima';
      bg = const Color(0xFFE3FCEC);
      dot = const Color(0xFF16A34A);
      truck = const Color(0xFF16A34A);
    } else if (external.contains('HILANG') ||
        external.contains('LOST') ||
        external.contains('CANCEL') ||
        external.contains('RETURN')) {
      label = 'Bermasalah';
      bg = const Color(0xFFFEE2E2);
      dot = const Color(0xFFB91C1C);
      truck = const Color(0xFFB91C1C);
    } else if (external.isNotEmpty) {
      // status lain dari binderbyte → tetap “Dalam proses” (biru)
      label = 'Dalam proses';
    } else {
      // kalau belum ada external status: pakai status internal locker
      if (internal == 'completed') {
        label = 'Sudah diambil';
        bg = const Color(0xFFE3FCEC);
        dot = const Color(0xFF16A34A);
        truck = const Color(0xFF16A34A);
      } else if (internal == 'delivered_to_locker' ||
          internal == 'ready_for_pickup') {
        label = 'Siap diambil';
        bg = const Color(0xFFE3FCEC);
        dot = const Color(0xFF16A34A);
        truck = const Color(0xFF16A34A);
      } else if (internal == 'pending_locker') {
        label = 'Dalam proses';
      }
    }

    return (label: label, bg: bg, dot: dot, truck: truck);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchShipments,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _shipments.isEmpty
                  ? const Center(child: Text('Belum ada data paket.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _shipments.length,
                      itemBuilder: (context, index) {
                        final s = _shipments[index];

                        final String resi = (s['resi'] ?? '').toString();
                        final String courierType =
                            (s['courierType'] ?? '').toString();
                        final String internalStatus =
                            (s['status'] ?? 'pending_locker').toString();

                        final visual = _statusVisual(s);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TrackingDetailPage(
                                    resi: resi,
                                    courierType: courierType,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // badge status di atas
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: visual.bg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: visual.dot,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          visual.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: visual.dot,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.local_shipping,
                                          color: visual.truck, size: 32),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              resi,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$courierType · $internalStatus',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
