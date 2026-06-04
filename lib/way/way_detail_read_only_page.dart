import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WayDetailReadOnlyPage extends StatefulWidget {
  final Map<String, dynamic> wayData;

  const WayDetailReadOnlyPage({super.key, required this.wayData});

  @override
  State<WayDetailReadOnlyPage> createState() => _WayDetailReadOnlyPageState();
}

class _WayDetailReadOnlyPageState extends State<WayDetailReadOnlyPage> {
  final supabase = Supabase.instance.client;

  List<dynamic> _historyList = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await supabase
          .from('way_history')
          .select()
          .eq('way_id', widget.wayData['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _historyList = response;
          _isLoadingHistory = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading timeline: $error')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'picked_up': return Colors.blue;
      case 'delivering': return Colors.purple;
      case 'dropped': case 'delivered': return Colors.green;
      case 'rejected': case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString).toLocal();
    final padMin = date.minute.toString().padLeft(2, '0');
    return "${date.day}/${date.month}/${date.year} at ${date.hour}:$padMin";
  }

  Widget _buildTimeline() {
    if (_isLoadingHistory) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    }

    if (_historyList.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16.0), child: Text('No history found for this delivery.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _historyList.length,
      itemBuilder: (context, index) {
        final history = _historyList[index];
        final status = history['status'] ?? 'unknown';
        final remark = history['remark'];
        final color = _getStatusColor(status);
        final isLast = index == _historyList.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      margin: const EdgeInsets.only(top: 4),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey.shade300,
                          margin: const EdgeInsets.only(top: 4, bottom: 4),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(history['created_at']),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (remark != null && remark.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text('Note: $remark', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.wayData['status'] ?? 'pending';
    final customerName = widget.wayData['customer']?['full_name'] ?? 'Unknown Customer';
    final riderName = widget.wayData['rider']?['full_name'] ?? 'Unassigned';
    final remark = widget.wayData['remark'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.wayData['id']}'),
        // No action buttons in the AppBar!
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Status
            Center(
              child: Column(
                children: [
                  Chip(
                    label: Text(
                      status.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: _getStatusColor(status),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  if (remark != null && remark.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.note, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(child: Text(remark, style: const TextStyle(fontStyle: FontStyle.italic))),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Routing Info
            const Text('Routing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Pickup: ${widget.wayData['pickup_location']}', style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Drop: ${widget.wayData['drop_location']}', style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Personnel Info
            const Text('Assigned Personnel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: const Text('Customer'),
                      subtitle: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.motorcycle, color: Colors.white)),
                      title: const Text('Rider'),
                      subtitle: Text(riderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Timeline
            const Text('Delivery Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTimeline(),

          ],
        ),
      ),
    );
  }
}