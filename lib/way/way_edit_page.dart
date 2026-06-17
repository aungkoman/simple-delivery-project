import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simpledelivery/way/way_detail_read_only_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayEditPage extends StatefulWidget {
  final Map<String, dynamic> wayData;

  const WayEditPage({super.key, required this.wayData});

  @override
  State<WayEditPage> createState() => _WayEditPageState();
}

class _WayEditPageState extends State<WayEditPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // --- NEW: Scroll and Key management ---
  final ScrollController _statusScrollController = ScrollController();
  late List<GlobalKey> _statusKeys;

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();

  // --- NEW: Finance Controllers ---
  final _deliveryChargesController = TextEditingController();
  final _riderFeeController = TextEditingController();
  final _parcelValueController = TextEditingController();
  final _amountToCollectController = TextEditingController();


  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _riders = [];

  String? _selectedCustomerId;
  String? _selectedRiderId;
  late String _selectedStatus;

  // --- Image Management State ---
  final ImagePicker _picker = ImagePicker();
  List<String> _existingImageUrls = []; // Images already on Supabase
  List<File> _newLocalImages = [];      // New images picked from device
  List<String> _deletedImageUrls = [];  // Track URLs the user wants to delete

  // --- NEW: Finance State & Status Tracking ---
  String _paymentType = 'prepaid';
  String _whoPaid = 'sender';
  String _payStatus = 'pending';
  String _riderFeeStatus = 'pending';
  String _senderPayoutStatus = 'pending';


  final List<Map<String, String>> _statusOptions = [
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'preparing', 'label': 'Preparing'},
    {'value': 'assigned', 'label': 'Assigned'},
    {'value': 'picked_up', 'label': 'Picked Up'},
    {'value': 'delivering', 'label': 'Delivering'},
    {'value': 'dropped', 'label': 'Delivered'},
    {'value': 'cancelled', 'label': 'Cancelled'},
  ];

  final Map<String, String> _payStatusOptions = {
    'prepaid': 'Prepaid',
    'pending': 'Pending',
    'collected': 'Collected',
    'remitted_to_office': 'Remitted to Office',
    'lost': 'Lost',
  };

  final Map<String, String> _riderFeeStatusOptions = {
    'pending': 'Pending',
    'settled': 'Settled',
    'refund': 'Refund',
  };

  final Map<String, String> _senderPayoutStatusOptions = {
    'not_applicable': 'Not Applicable',
    'pending': 'Pending',
    'advanced_paid': 'Advanced Paid',
    'settled': 'Settled',
    'refund_requested': 'Refund Requested',
    'refunded_by_sender': 'Refunded by Sender',
  };


  @override
  void initState() {
    super.initState();

    // Initialize keys for every status option
    _statusKeys = List.generate(_statusOptions.length, (index) => GlobalKey());

    _pickupController.text = widget.wayData['pickup_location'] ?? '';
    _dropController.text = widget.wayData['drop_location'] ?? '';
    _descriptionController.text = widget.wayData['description'] ?? '';
    _remarkController.text =  widget.wayData['remark'] ?? '';

    // Load existing images if they exist
    if (widget.wayData['images'] != null) {
      _existingImageUrls = List<String>.from(widget.wayData['images']);
    }


    _selectedCustomerId = widget.wayData['customer_id'];
    _selectedRiderId = widget.wayData['rider_id'];

    final currentStatus = widget.wayData['status']?.toString().toLowerCase() ?? 'pending';
    final validValues = _statusOptions.map((opt) => opt['value']).toList();
    _selectedStatus = validValues.contains(currentStatus) ? currentStatus : 'pending';

    // --- NEW: Initialize Finance Fields ---
    _parcelValueController.text = (widget.wayData['parcel_value'] ?? 0.0).toStringAsFixed(0);
    _deliveryChargesController.text = (widget.wayData['delivery_charges'] ?? 0.0).toStringAsFixed(0);
    _amountToCollectController.text = (widget.wayData['amount_to_collect'] ?? 0.0).toStringAsFixed(0);
    _riderFeeController.text = (widget.wayData['rider_fee'] ?? 0.0).toStringAsFixed(0);


    // --- NEW: Initialize Finance States ---
    _paymentType = widget.wayData['payment_type'] ?? 'prepaid';
    _whoPaid = widget.wayData['who_paid'] ?? 'sender';
    _payStatus = widget.wayData['pay_status'] ?? 'pending';
    _riderFeeStatus = widget.wayData['rider_fee_status'] ?? 'pending';
    _senderPayoutStatus = widget.wayData['sender_payout_status'] ?? 'pending';

    _fetchUsersForDropdowns();

    // --- NEW: Center the selected status after the first frame ---
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedStatus());
  }

  // --- NEW: Centering Logic ---
  void _scrollToSelectedStatus() {
    final index = _statusOptions.indexWhere((opt) => opt['value'] == _selectedStatus);
    if (index != -1) {
      final context = _statusKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5, // 0.5 centers the element in the viewport
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  // --- UX: Auto-Calculate Finance ---
  void _calculateAmountToCollect() {
    if (_paymentType == 'cod') {
      double parcel = double.tryParse(_parcelValueController.text) ?? 0;
      double delivery = double.tryParse(_deliveryChargesController.text) ?? 0;

      double total = parcel;
      if (_whoPaid == 'receiver') {
        total += delivery;
      }

      String newTotal = total.toStringAsFixed(0);
      if (_amountToCollectController.text != newTotal) {
        _amountToCollectController.text = newTotal;
      }
    } else {
      if (_amountToCollectController.text != '0') {
        _amountToCollectController.text = '0';
      }
    }
  }

  void _onPaymentStateChanged() {
    _calculateAmountToCollect();
    setState(() {});
  }


  @override
  void dispose() {
    _statusScrollController.dispose(); // Clean up controller
    _pickupController.dispose();
    _dropController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  // --- Image Pick & Remove Methods ---
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 70);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newLocalImages.addAll(pickedFiles.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
    }
  }


  void _removeExistingImage(int index) {
    setState(() {
      _deletedImageUrls.add(_existingImageUrls[index]); // Mark for deletion on backend
      _existingImageUrls.removeAt(index);               // Remove from UI
    });
  }

  void _removeNewLocalImage(int index) {
    setState(() {
      _newLocalImages.removeAt(index);
    });
  }


  // ... _fetchUsersForDropdowns and _updateWay remain the same as previous step ...
  Future<void> _fetchUsersForDropdowns() async {
    try {
      String customerFilter = 'is_deleted.eq.false';
      if (_selectedCustomerId != null) {
        customerFilter = 'is_deleted.eq.false,id.eq.$_selectedCustomerId';
      }

      String riderFilter = 'is_deleted.eq.false';
      if (_selectedRiderId != null) {
        riderFilter = 'is_deleted.eq.false,id.eq.$_selectedRiderId';
      }

      final customerResponse = await supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('role', 'customer')
          .or(customerFilter)
          .order('full_name');

      final riderResponse = await supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('role', 'rider')
          .or(riderFilter)
          .order('full_name');

      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(customerResponse);
          _riders = List<Map<String, dynamic>>.from(riderResponse);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateWay() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final random = Random();
      List<String> finalImageUrls = List.from(_existingImageUrls);

      // 1. DELETE removed images from Supabase Storage bucket
      if (_deletedImageUrls.isNotEmpty) {
        for (String url in _deletedImageUrls) {
          // Extract the storage path from the public URL.
          // (Assuming standard public URL format: .../storage/v1/object/public/way_images/PATH)
          final uri = Uri.parse(url);
          final pathSegments = uri.pathSegments;
          // Find 'way_images' and get everything after it
          final bucketIndex = pathSegments.indexOf('way_images');
          if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
            final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await supabase.storage.from('way_images').remove([storagePath]);
          }
        }
      }

      // 2. UPLOAD new images to Supabase Storage
      for (File imageFile in _newLocalImages) {
        final fileExt = imageFile.path.split('.').last;
        final randomString = random.nextInt(1000000).toString();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$randomString.$fileExt';

        final filePath = '$_selectedCustomerId/$fileName';

        await supabase.storage.from('way_images').upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        final String publicUrl = supabase.storage.from('way_images').getPublicUrl(filePath);
        finalImageUrls.add(publicUrl);
      }


      // 3. PARSE FINANCIAL DATA
      final deliveryCharges = double.tryParse(_deliveryChargesController.text.trim()) ?? 0.0;
      final riderFee = double.tryParse(_riderFeeController.text.trim()) ?? 0.0;
      final parcelValue = double.tryParse(_parcelValueController.text.trim()) ?? 0.0;
      final amountToCollect = double.tryParse(_amountToCollectController.text.trim()) ?? 0.0;

      await supabase.from('ways').update({
        'customer_id': _selectedCustomerId,
        'rider_id': _selectedRiderId,
        'pickup_location': _pickupController.text.trim(),
        'drop_location': _dropController.text.trim(),
        'description': _descriptionController.text.trim(),
        'remark': _remarkController.text.trim(),
        'status': _selectedStatus,
        'images': finalImageUrls, // Save the updated array of URLs

        // Updated Finance Fields
        'payment_type': _paymentType,
        'who_paid': _whoPaid,
        'delivery_charges': deliveryCharges,
        'rider_fee': riderFee,
        'parcel_value': parcelValue,
        'amount_to_collect': amountToCollect,

        // Updated Trackers
        'pay_status': _payStatus,
        'rider_fee_status': _riderFeeStatus,
        'sender_payout_status': _senderPayoutStatus,

      }).eq('id', widget.wayData['id']);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Color _getStatusThemeColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade600;
      case 'preparing': return Colors.amber.shade700;
      case 'assigned': return Colors.teal.shade600;
      case 'picked_up': return Colors.blue.shade600;
      case 'delivering': return Colors.purple.shade600;
      case 'dropped': return Colors.green.shade600;
      case 'cancelled': return Colors.red.shade600;
      default: return Colors.indigo.shade600;
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo.shade400, size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade600, width: 2)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }


  Widget _buildHorizontalChoiceChips({
    required Map<String, String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    Color activeColor = Colors.indigo,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.entries.map((entry) {
          final bool isSelected = selectedValue == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected && selectedValue != entry.key) {
                  onSelected(entry.key);
                }
              },
              showCheckmark: false,
              selectedColor: activeColor.withOpacity(0.15),
              backgroundColor: Colors.grey.shade100,
              side: BorderSide(color: isSelected ? activeColor : Colors.transparent, width: 1.5),
              labelStyle: TextStyle(
                color: isSelected ? activeColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String initialRiderText = '';
    if (!_isLoading && _selectedRiderId != null) {
      try {
        final currentRider = _riders.firstWhere((r) => r['id'] == _selectedRiderId);
        initialRiderText = '${currentRider['full_name']} (${currentRider['phone'] ?? 'No Phone'})';
      } catch (e) {}
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text('Edit Order #${widget.wayData['id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => WayDetailReadOnlyPage(wayData: widget.wayData)));
            }, icon: Icon(Icons.eighteen_mp))
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.indigo.shade700))
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text('Operational Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),

                      // --- SCROLLABLE STATUS CHIPS WITH CENTERING ---
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          controller: _statusScrollController, // Attach controller
                          scrollDirection: Axis.horizontal,
                          itemCount: _statusOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = _statusOptions[index];
                            final value = item['value']!;
                            final label = item['label']!;
                            final isSelected = _selectedStatus == value;
                            final themeColor = _getStatusThemeColor(value);

                            return Padding(
                              key: _statusKeys[index], // Assign key for ensureVisible
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                labelStyle: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                                selectedColor: themeColor,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setState(() => _selectedStatus = value);
                                    // Center the chip when manually tapped as well
                                    _scrollToSelectedStatus();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ... Rest of UI (Personnel, Details, Buttons) remains the same ...
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text('Assigned Personnel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      DropdownButtonFormField<String>(
                        value: _customers.any((c) => c['id'] == _selectedCustomerId) ? _selectedCustomerId : null,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: _buildInputDecoration('Customer (Required)', Icons.person_outline),
                        items: _customers.map<DropdownMenuItem<String>>((customer) {
                          return DropdownMenuItem<String>(
                            value: customer['id'],
                            child: Text('${customer['full_name']} (${customer['phone'] ?? '...'})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCustomerId = value),
                      ),
                      const SizedBox(height: 16),
                      Autocomplete<Map<String, dynamic>>(
                        initialValue: TextEditingValue(text: initialRiderText),
                        displayStringForOption: (option) => '${option['full_name']} (${option['phone'] ?? 'N/A'})',
                        optionsBuilder: (val) => val.text.isEmpty ? _riders : _riders.where((r) => r['full_name'].toLowerCase().contains(val.text.toLowerCase())),
                        onSelected: (selection) => setState(() => _selectedRiderId = selection['id']),
                        fieldViewBuilder: (ctx, ctrl, focus, onComplete) {
                          return TextFormField(
                            controller: ctrl,
                            focusNode: focus,
                            decoration: _buildInputDecoration('Search Assigned Rider', Icons.motorcycle_outlined).copyWith(
                              suffixIcon: _selectedRiderId != null ? IconButton(icon: Icon(Icons.clear, color: Colors.red), onPressed: () { ctrl.clear(); setState(() => _selectedRiderId = null); }) : Icon(Icons.search),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: const Text('Delivery Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      TextFormField(controller: _descriptionController, decoration: _buildInputDecoration('Package Description', Icons.inventory_2_outlined)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _pickupController, decoration: _buildInputDecoration('Pickup', Icons.radio_button_checked)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _dropController, decoration: _buildInputDecoration('Drop-off', Icons.location_on)),
                      const SizedBox(height: 16),
                      TextFormField(controller: _remarkController, maxLines: 2, decoration: _buildInputDecoration('Remarks', Icons.note_alt_outlined)),
                      const SizedBox(height: 100),

                      // --- IMAGE EDITING SECTION ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Package Images'),
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_photo_alternate, size: 18),
                            label: const Text('Add Images'),
                          )
                        ],
                      ),

                      // Check if we have ANY images (old or new) to show
                      if (_existingImageUrls.isNotEmpty || _newLocalImages.isNotEmpty)
                        Container(
                          height: 110,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              // 1. Render Existing Supabase Images
                              ..._existingImageUrls.asMap().entries.map((entry) {
                                int idx = entry.key;
                                String url = entry.value;
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 12, top: 8),
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.indigo.shade200, width: 2),
                                        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeExistingImage(idx),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.delete_forever, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),

                              // 2. Render Newly Picked Local Images
                              ..._newLocalImages.asMap().entries.map((entry) {
                                int idx = entry.key;
                                File file = entry.value;
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 12, top: 8),
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade400, width: 2),
                                        image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeNewLocalImage(idx),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                    // Visual indicator that this is unsaved
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    )
                                  ],
                                );
                              }),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24, left: 4),
                          child: Text('No images attached to this delivery.', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                        ),

                      // --- NEW: Finance Section ---
                      _buildSectionHeader('ငွေကြေးဆိုင်ရာ အချက်အလက်များ (Financial Details)'),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ပစ္စည်း ငွေချေစနစ် (Payment Type)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('COD'),
                                      selected: _paymentType == 'cod',
                                      onSelected: (_) { _paymentType = 'cod'; _onPaymentStateChanged(); },
                                      selectedColor: Colors.green.shade100,
                                      backgroundColor: Colors.grey.shade200,
                                      showCheckmark: false,
                                    ),
                                    ChoiceChip(
                                      label: const Text('Prepaid'),
                                      selected: _paymentType == 'prepaid',
                                      onSelected: (_) { _paymentType = 'prepaid'; _onPaymentStateChanged(); },
                                      selectedColor: Colors.green.shade100,
                                      backgroundColor: Colors.grey.shade200,
                                      showCheckmark: false,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ပို့ဆောင်ခရှင်းမည့်သူ (Who Paid)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Receiver'),
                                      selected: _whoPaid == 'receiver',
                                      onSelected: (_) { _whoPaid = 'receiver'; _onPaymentStateChanged(); },
                                      selectedColor: Colors.green.shade100,
                                      backgroundColor: Colors.grey.shade200, // <-- Makes the inactive chip grey
                                      showCheckmark: false,
                                    ),
                                    ChoiceChip(
                                      label: const Text('Sender'),
                                      selected: _whoPaid == 'sender',
                                      onSelected: (_) { _whoPaid = 'sender'; _onPaymentStateChanged(); },
                                      selectedColor: Colors.green.shade100,
                                      backgroundColor: Colors.grey.shade200, // <-- Makes the inactive chip grey
                                      showCheckmark: false,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _parcelValueController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                              decoration: _buildInputDecoration('ပစ္စည်းတန်ဖိုး', Icons.inventory),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _deliveryChargesController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                              decoration: _buildInputDecoration('ပို့ဆောင်ခ', Icons.local_shipping),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _amountToCollectController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                              decoration: _buildInputDecoration('ကောက်ခံရန်ငွေ', Icons.account_balance_wallet).copyWith(
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _riderFeeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                              decoration: _buildInputDecoration('Rider ရမည့်ငွေ', Icons.sports_motorsports),
                            ),
                          ),
                        ],
                      ),

                      // --- NEW: Status Trackers ---
                      const Text('Customer Payment Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 8),
                      _buildHorizontalChoiceChips(
                        options: _payStatusOptions,
                        selectedValue: _payStatus,
                        activeColor: Colors.blue.shade700,
                        onSelected: (val) => setState(() => _payStatus = val),
                      ),
                      const SizedBox(height: 20),
                      const Text('Rider Fee Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 8),
                      _buildHorizontalChoiceChips(
                        options: _riderFeeStatusOptions,
                        selectedValue: _riderFeeStatus,
                        activeColor: Colors.orange.shade700,
                        onSelected: (val) => setState(() => _riderFeeStatus = val),
                      ),
                      const SizedBox(height: 20),
                      const Text('Sender Payout Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 8),
                      _buildHorizontalChoiceChips(
                        options: _senderPayoutStatusOptions,
                        selectedValue: _senderPayoutStatus,
                        activeColor: Colors.purple.shade700,
                        onSelected: (val) => setState(() => _senderPayoutStatus = val),
                      ),
                      const SizedBox(height: 28),




                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(20),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _updateWay,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white, minimumSize: Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isSubmitting ? CircularProgressIndicator(color: Colors.white) : Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}