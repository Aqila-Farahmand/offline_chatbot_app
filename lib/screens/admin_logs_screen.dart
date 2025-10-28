import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/csv_download.dart';
import '../config/admin_config.dart';

class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  bool _isAdmin(User? user) {
    if (user == null) return false;

    final email = user.email ?? '';
    return AdminConfig.adminEmails.contains(email) ||
        AdminConfig.adminUids.contains(user.uid);
  }

  String _rowToCsv(Map<String, dynamic> d) {
    String q(String s) =>
        '"${s.replaceAll('"', '""').replaceAll('\n', ' ').replaceAll('\r', ' ')}"';
    return [
      d['timestamp_iso']?.toString() ?? '',
      d['uid']?.toString() ?? '',
      d['model_name']?.toString() ?? '',
      d['prompt_label']?.toString() ?? '',
      d['question']?.toString() ?? '',
      d['response']?.toString() ?? '',
      (d['response_time_ms'] ?? '').toString(),
      d['platform']?.toString() ?? '',
    ].map((s) => q(s)).join(',');
  }

  Future<void> _downloadCsv(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final header =
        'timestamp_iso,uid,model_name,prompt_label,question,response,response_time_ms,platform\n';
    final rows = docs.map((d) => _rowToCsv(d.data())).join('\n');
    final ok = await downloadCsv(
      'chat_logs_export.csv',
      header + rows + (rows.isEmpty ? '' : '\n'),
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV download not supported on this platform.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: Chat Logs')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          final user = authSnap.data;
          if (!_isAdmin(user)) {
            return const Center(child: Text('Access denied'));
          }
          final query = FirebaseFirestore.instance
              .collection('chat_logs')
              .orderBy('timestamp_iso', descending: true)
              .limit(1000);
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final docs = snapshot.data?.docs ?? const [];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: docs.isEmpty
                              ? null
                              : () => _downloadCsv(context, docs),
                          icon: const Icon(Icons.download),
                          label: const Text('Download CSV'),
                        ),
                        const SizedBox(width: 12),
                        Text('Rows: ${docs.length}'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        return ListTile(
                          dense: true,
                          title: Text(data['question']?.toString() ?? ''),
                          subtitle: Text(data['response']?.toString() ?? ''),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(data['model_name']?.toString() ?? ''),
                              Text('${data['response_time_ms'] ?? ''} ms'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: kIsWeb
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Use web to download CSV, or export Firestore externally.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('Help'),
            ),
    );
  }
}
