import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/searchable_dropdown.dart';

/// Agent page for inputting shipment data with searchable dropdowns
/// This is the "Input Pengiriman" form for agents
class AgentInputPage extends StatefulWidget {
  const AgentInputPage({super.key});

  @override
  State<AgentInputPage> createState() => _AgentInputPageState();
}

class _AgentInputPageState extends State<AgentInputPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _resiController = TextEditingController();
  final _courierTypeController = TextEditingController();
  
  // Selected values from searchable dropdowns
  String _selectedLockerId = '';
  String _selectedCustomerId = '';
  
  // Available options loaded from server
  List<DropdownItem> _lockerOptions = [];
  List<DropdownItem> _customerOptions = [];
  
  bool _loading = false;
  bool _loadingData = true;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _resiController.dispose();
    _courierTypeController.dispose();
    super.dispose();
  }

  /// Load available lockers and customers from server
  Future<void> _loadDropdownData() async {
    setState(() {
      _loadingData = true;
      _error = null;
    });

    try {
      // Fetch available lockers
      final lockersResp = await ApiClient.get('/api/agent/lockers', auth: true);
      if (lockersResp.statusCode == 200) {
        final data = jsonDecode(lockersResp.body);
        final list = (data['data'] as List?) ?? [];
        _lockerOptions = list.map<DropdownItem>((e) => DropdownItem(
          id: e['id']?.toString() ?? '',
          label: e['lockerId']?.toString() ?? e['id']?.toString() ?? '',
          subtitle: e['location']?.toString(),
        )).toList();
      }

      // Fetch available customers
      final customersResp = await ApiClient.get('/api/agent/customers', auth: true);
      if (customersResp.statusCode == 200) {
        final data = jsonDecode(customersResp.body);
        final list = (data['data'] as List?) ?? [];
        _customerOptions = list.map<DropdownItem>((e) => DropdownItem(
          id: e['customerId']?.toString() ?? e['id']?.toString() ?? '',
          label: e['customerId']?.toString() ?? e['id']?.toString() ?? '',
          subtitle: e['name']?.toString(),
        )).toList();
      }

      setState(() {
        _loadingData = false;
      });
    } catch (e) {
      setState(() {
        _loadingData = false;
        _error = 'Failed to load data: $e';
      });
    }
  }

  /// Validate 6-digit customer ID format
  String? _validateCustomerId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Customer ID is required';
    }
    // Allow 6-digit format validation
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Customer ID must be 6 digits';
    }
    return null;
  }

  /// Validate locker ID
  String? _validateLockerId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Locker ID is required';
    }
    return null;
  }

  /// Submit the shipment form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final resp = await ApiClient.post(
        '/api/agent/shipments',
        {
          'lockerId': _selectedLockerId,
          'customerId': _selectedCustomerId,
          'resi': _resiController.text.trim(),
          'courierType': _courierTypeController.text.trim(),
        },
        auth: true,
      );

      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        setState(() {
          _successMessage = data['message']?.toString() ?? 'Shipment created successfully!';
        });
        
        // Clear form after successful submission
        _clearForm();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_successMessage!),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _error = data['error']?.toString() ?? 'Failed to create shipment';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Clear the form
  void _clearForm() {
    _resiController.clear();
    _courierTypeController.clear();
    setState(() {
      _selectedLockerId = '';
      _selectedCustomerId = '';
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Pengiriman'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDropdownData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const Text(
                        'Form Input Pengiriman',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan data pengiriman paket ke locker',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Locker ID - Searchable Dropdown
                      SearchableDropdown<DropdownItem>(
                        label: 'Locker ID *',
                        hint: 'Cari atau ketik Locker ID',
                        items: _lockerOptions,
                        itemToString: (item) => item.label,
                        prefixIcon: Icons.lock_outline,
                        filterFn: (item, query) {
                          return item.label.toLowerCase().contains(query.toLowerCase()) ||
                              (item.subtitle?.toLowerCase().contains(query.toLowerCase()) ?? false);
                        },
                        validator: _validateLockerId,
                        onChanged: (value, selectedItem) {
                          setState(() {
                            _selectedLockerId = selectedItem?.id ?? value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Customer ID - Searchable Dropdown
                      SearchableDropdown<DropdownItem>(
                        label: 'Customer ID (6 digit) *',
                        hint: 'Cari atau ketik Customer ID',
                        items: _customerOptions,
                        itemToString: (item) => item.label,
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.number,
                        filterFn: (item, query) {
                          return item.label.contains(query) ||
                              (item.subtitle?.toLowerCase().contains(query.toLowerCase()) ?? false);
                        },
                        validator: _validateCustomerId,
                        onChanged: (value, selectedItem) {
                          setState(() {
                            _selectedCustomerId = selectedItem?.id ?? value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Resi/Tracking Number
                      TextFormField(
                        controller: _resiController,
                        decoration: const InputDecoration(
                          labelText: 'Nomor Resi *',
                          hintText: 'Contoh: JNE1234567890',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nomor resi wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Courier Type
                      TextFormField(
                        controller: _courierTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Jenis Kurir *',
                          hintText: 'Contoh: JNE, JNT, SICEPAT',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jenis kurir wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Success message
                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: TextStyle(color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Submit button
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _loading ? null : _clearForm,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Simpan Pengiriman'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
