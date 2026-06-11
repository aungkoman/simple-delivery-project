import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiderDetailPage extends StatefulWidget {
  final String riderId;
  final String riderName;

  const RiderDetailPage({
    super.key,
    required this.riderId,
    required this.riderName,
  });

  @override
  State<RiderDetailPage> createState() => _RiderDetailPageState();
}

class _RiderDetailPageState extends State<RiderDetailPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _locationRecords = [];

  @override
  void initState() {
    super.initState();
    _fetchDailyRecords();
  }

  Future<void> _fetchDailyRecords() async {
    try {
      // Fetch the last 100 location pings for this rider, newest first.
      // If you have an "orders" or "trips" table, you would query that here instead.
      final response = await supabase
          .from('rider_locations')
          .select()
          .eq('rider_id', widget.riderId)
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _locationRecords = response;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching records: $error')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');

      final hours = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      final minutes = date.minute.toString().padLeft(2, '0');

      return "$date.year-$month-$day  |  $hours:$minutes $period";
    } catch (_) {
      return 'Unknown Time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.riderName}\'s Records', style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : _locationRecords.isEmpty
          ? Center(
        child: Text(
          'No records found for ${widget.riderName}.',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _locationRecords.length,
        itemBuilder: (context, index) {
          final record = _locationRecords[index];
          final lat = (record['latitude'] as num).toStringAsFixed(5);
          final lng = (record['longitude'] as num).toStringAsFixed(5);

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade50,
                child: Icon(Icons.location_on, color: Colors.indigo.shade400),
              ),
              title: Text(
                _formatDateTime(record['created_at']),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Lat: $lat, Lng: $lng',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                // Optional: You could open a single-marker map here
                // to show exactly where this specific ping occurred.
              },
            ),
          );
        },
      ),
    );
  }
}