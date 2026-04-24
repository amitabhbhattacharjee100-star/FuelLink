import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Displays historical Ontario gas price snapshots from Firestore.
/// Data is written by the Cloud Function daily at 7 AM EST.
class PriceHistoryScreen extends StatelessWidget {
  const PriceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Price History"),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('priceHistory')
            .orderBy('timestamp', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      "Could not load price history.\n${snapshot.error}",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No price history yet.\nCheck back after the first daily email is sent at 7 AM EST.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final avgPrice = (data['averagePrice'] as num?)?.toDouble() ?? 0;
              final cheapestPrice =
                  (data['cheapestPrice'] as num?)?.toDouble() ?? 0;
              final expensivePrice =
                  (data['expensivePrice'] as num?)?.toDouble() ?? 0;
              final volatility = (data['volatility'] as num?)?.toDouble() ?? 0;
              final cheapestCity = data['cheapestCity'] as String? ?? '—';
              final totalStations = data['totalStations'] as int? ?? 0;
              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? _formatDate(timestamp.toDate())
                  : 'Unknown date';

              final sentimentColor = volatility > 5
                  ? Colors.red
                  : volatility > 2
                      ? Colors.orange
                      : Colors.green;
              final sentimentLabel = volatility > 5
                  ? 'High'
                  : volatility > 2
                      ? 'Normal'
                      : 'Low';

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(date,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: sentimentColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sentimentColor),
                            ),
                            child: Text(
                              '$sentimentLabel Volatility',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: sentimentColor,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Price stats grid
                      Row(
                        children: [
                          _statBox("Avg", avgPrice, Colors.blue),
                          const SizedBox(width: 8),
                          _statBox("Cheapest", cheapestPrice, Colors.green),
                          const SizedBox(width: 8),
                          _statBox("Highest", expensivePrice, Colors.red),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Footer info
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Cheapest city: $cheapestCity  •  $totalStations stations',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ),
                          Text(
                            '±${volatility.toStringAsFixed(1)}%',
                            style:
                                TextStyle(fontSize: 11, color: sentimentColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statBox(String label, double price, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${price.toStringAsFixed(1)}¢',
                style: TextStyle(
                    fontSize: 15,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
