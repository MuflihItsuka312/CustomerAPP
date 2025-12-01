import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// sesuaikan alamat backend
const String backendBaseUrl = 'https://serverr.shidou.cloud';

class TrackingDetailPage extends StatefulWidget {
  final String resi;
  final String courierType;

  const TrackingDetailPage({
    Key? key,
    required this.resi,
    required this.courierType,
  }) : super(key: key);

  @override
  State<TrackingDetailPage> createState() => _TrackingDetailPageState();
}

class _TrackingDetailPageState extends State<TrackingDetailPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _detail;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchTracking();
  }

  Future<void> _fetchTracking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ REMOVED courier query param - backend auto-detects now
      final uri = Uri.parse('$backendBaseUrl/api/customer/track/${widget.resi}');
      
      print('[TRACKING] Fetching: $uri');
      
      final resp = await http.get(uri);
      
      print('[TRACKING] Status: ${resp.statusCode}');
      print('[TRACKING] Body: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        // ✅ FIXED: Access binderbyte directly
        final binderbyte = data['binderbyte'];
        
        if (binderbyte != null) {
          setState(() {
            _summary = binderbyte['summary'] as Map<String, dynamic>?;
            _detail = binderbyte['detail'] as Map<String, dynamic>?;
            _history = (binderbyte['history'] as List?) ?? [];
            _loading = false;
          });
          
          print('[TRACKING] ✅ Loaded ${_history.length} history items');
        } else {
          setState(() {
            _error = 'Tracking dari ekspedisi belum tersedia';
            _loading = false;
          });
          
          print('[TRACKING] ⚠️ No binderbyte data');
        }
      } else {
        final errorData = jsonDecode(resp.body);
        setState(() {
          _error = errorData['error'] ?? 'Gagal load tracking (${resp.statusCode})';
          _loading = false;
        });
        
        print('[TRACKING] ❌ Error: $_error');
      }
    } catch (e) {
      setState(() {
        _error = 'Error koneksi: $e';
        _loading = false;
      });
      
      print('[TRACKING] ❌ Exception: $e');
    }
  }

  Color _statusColor(String status) {
    final s = status.toUpperCase();
    if (s.contains('DELIVERED') || s.contains('DELIVERY SUKSES')) {
      return Colors.green; // diterima
    }
    if (s.contains('HILANG') ||
        s.contains('LOST') ||
        s.contains('CANCEL')) {
      return Colors.red; // dibatalkan / hilang
    }
    // ON PROCESS / IN TRANSIT / dll
    return Colors.blue;
  }

  String _statusLabel(String status) {
    final s = status.toUpperCase();
    if (s.contains('DELIVERED') || s.contains('DELIVERY SUKSES')) {
      return 'Diterima';
    }
    if (s.contains('HILANG') ||
        s.contains('LOST') ||
        s.contains('CANCEL')) {
      return 'Dibatalkan / Hilang';
    }
    return 'Sedang dikirim';
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Detail ${widget.resi}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTracking,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _summary == null
                  ? const Center(child: Text('Tidak ada data tracking.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(),
                          const SizedBox(height: 16),
                          _buildHistory(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSummaryCard() {
    final statusRaw = (_summary?['status'] ?? '').toString();
    final statusColor = _statusColor(statusRaw);
    final statusText = _statusLabel(statusRaw);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.resi,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (_summary?['courier'] ?? widget.courierType).toString(),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 10, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusRaw,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dari: ${_detail?['origin'] ?? '-'}',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            'Ke: ${_detail?['destination'] ?? '-'}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Tanggal: ${_summary?['date'] ?? '-'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return const Text('Belum ada riwayat tracking.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Riwayat Pengiriman',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          separatorBuilder: (_, __) => const Divider(height: 12),
          itemBuilder: (context, index) {
            final h = _history[index] as Map<String, dynamic>;
            final date = (h['date'] ?? '').toString();
            final desc = (h['desc'] ?? '').toString();
            final location = (h['location'] ?? '').toString();

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timeline, size: 20),
              title: Text(
                desc,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  if (location.isNotEmpty)
                    Text(
                      location,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
