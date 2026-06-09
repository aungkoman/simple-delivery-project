import 'package:flutter/material.dart';

class NotificationDetailPage extends StatelessWidget {
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final String? imageUrl; // Added explicit image URL support

  const NotificationDetailPage({
    super.key,
    required this.title,
    required this.body,
    required this.payload,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Extracting image from payload data if it's not provided explicitly via the notification object
    final String? finalImageUrl = imageUrl ?? payload['image'] ?? payload['url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('အကြောင်းကြားစာ အသေးစိတ်'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE DISPLAY SECTION
            if (finalImageUrl != null && finalImageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  finalImageUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 220,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback UI if the image fails to download or URL is invalid
                    return Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('ပုံရိပ်ဖော်ပြရန် အခက်အခဲရှိနေပါသည်', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. TEXT CONTENT CARD
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : 'ခေါင်းစဉ်မရှိပါ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      body.isNotEmpty ? body : 'အကြောင်းအရာမရှိပါ။',
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. PAYLOAD DATA CARD
            const Text(
              "နောက်ဆက်တွဲ အချက်အလက်များ (Payload Data)",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: payload.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${entry.key}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text("${entry.value}")),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}