import 'package:flutter/material.dart';
import 'way_status_update_page.dart';

class WayDetailPage extends StatefulWidget {
  final Map<String, dynamic> wayData;

  const WayDetailPage({super.key, required this.wayData});

  @override
  State<WayDetailPage> createState() => _WayDetailPageState();
}

class _WayDetailPageState extends State<WayDetailPage> {
  // We keep a local copy of the data so we can update the UI instantly when returning from edits
  late Map<String, dynamic> _currentWayData;

  @override
  void initState() {
    super.initState();
    _currentWayData = Map.from(widget.wayData);
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

  @override
  Widget build(BuildContext context) {
    final status = _currentWayData['status'] ?? 'pending';
    final customerName = _currentWayData['customer']?['full_name'] ?? 'Unknown Customer';
    final riderName = _currentWayData['rider']?['full_name'] ?? 'Unassigned';
    final remark = _currentWayData['remark'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Way Details #${_currentWayData['id']}'),
        actions: [
          // Full Edit Button (for changing locations/users)
          IconButton(
            icon: const Icon(Icons.edit_document),
            tooltip: 'Full Edit',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WayStatusUpdatePage(wayData: _currentWayData)),
              );
              if (result == true) {
                Navigator.pop(context, true); // Pop back to list to trigger a full refresh
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header Status ---
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

            // --- Routing Card ---
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
                        Expanded(child: Text('Pickup: ${_currentWayData['pickup_location']}', style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Drop: ${_currentWayData['drop_location']}', style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Personnel Card ---
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

            // --- Quick Action Button ---
            ElevatedButton.icon(
              onPressed: () async {
                final bool? didUpdate = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WayStatusUpdatePage(wayData: _currentWayData)),
                );

                // If they updated the status/remark, go back to list to refresh the master data
                if (didUpdate == true) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.update),
              label: const Text('Update Status & Remark'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}