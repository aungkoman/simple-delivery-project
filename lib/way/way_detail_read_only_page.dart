import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:url_launcher/url_launcher.dart'; // Recommended for tap-to-call

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
          SnackBar(
            content: Text('Error loading timeline: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- HELPER METHODS ---

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade600;
      case 'picked_up': return Colors.blue.shade600;
      case 'delivering': return Colors.purple.shade600;
      case 'dropped':
      case 'delivered': return Colors.green.shade600;
      case 'rejected':
      case 'cancelled': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  String _formatDate(String isoString) {
    // Pro-tip: In production, use the 'intl' package (DateFormat) for better localization.
    final date = DateTime.parse(isoString).toLocal();
    final padMin = date.minute.toString().padLeft(2, '0');
    return "${date.day}/${date.month}/${date.year} • ${date.hour}:$padMin";
  }

  // Future<void> _makePhoneCall(String phoneNumber) async {
  //   final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
  //   if (await canLaunchUrl(launchUri)) {
  //     await launchUrl(launchUri);
  //   }
  // }

  // --- UI COMPONENTS ---

  Widget _buildHeader(ThemeData theme, String status, String? remark, String? description) {
    final statusColor = _getStatusColor(status);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: statusColor.withOpacity(0.5)),
          ),
          child: Text(
            status.toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (remark != null && remark.trim().isNotEmpty) _buildNoteCard(remark, Icons.warning_amber_rounded, Colors.orange),
        if (description != null && description.trim().isNotEmpty) _buildNoteCard(description, Icons.info_outline, Colors.blue),
      ],
    );
  }

  Widget _buildNoteCard(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Routing Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Modern Connected Routing UI
            IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      const Icon(Icons.radio_button_checked, color: Colors.blue, size: 20),
                      Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                      const Icon(Icons.location_on, color: Colors.red, size: 24),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRouteText(theme, 'Pickup', widget.wayData['pickup_location']),
                        const SizedBox(height: 24),
                        _buildRouteText(theme, 'Drop-off', widget.wayData['drop_location']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteText(ThemeData theme, String label, String? location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(location ?? 'Not specified', style: theme.textTheme.bodyLarge),
      ],
    );
  }

  Widget _buildPersonnelCard(ThemeData theme) {
    final customer = widget.wayData['customer'] ?? {};
    final rider = widget.wayData['rider'] ?? {};

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildPersonTile(
            title: 'Customer',
            name: customer['full_name'] ?? 'Unknown Customer',
            phone: customer['phone'] ?? 'N/A',
            icon: Icons.person_outline,
            theme: theme,
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildPersonTile(
            title: 'Assigned Rider',
            name: rider['full_name'] ?? 'Unassigned',
            phone: rider['phone'] ?? 'N/A',
            icon: Icons.motorcycle_outlined,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonTile({required String title, required String name, required String phone, required IconData icon, required ThemeData theme}) {
    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(title, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(phone, style: theme.textTheme.bodyMedium),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.phone, color: Colors.green),
        onPressed: () {
          // _makePhoneCall(phone);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling functionality requires url_launcher package')));
        },
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme) {
    if (_isLoadingHistory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_historyList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No history found for this delivery.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        ),
      );
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
                width: 30,
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)],
                      ),
                      margin: const EdgeInsets.only(top: 4),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey.shade200,
                          margin: const EdgeInsets.symmetric(vertical: 4),
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
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(history['created_at']),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                      if (remark != null && remark.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(remark, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
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
    final theme = Theme.of(context);
    final status = widget.wayData['status'] ?? 'pending';
    final remark = widget.wayData['remark'];
    final description = widget.wayData['description'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Subtle background color to make cards pop
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text('Order #${widget.wayData['id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme, status, remark, description),
            const SizedBox(height: 24),

            _buildRoutingCard(theme),
            const SizedBox(height: 24),

            Text('People', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPersonnelCard(theme),
            const SizedBox(height: 32),

            Text('Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTimeline(theme),
          ],
        ),
      ),
    );
  }
}