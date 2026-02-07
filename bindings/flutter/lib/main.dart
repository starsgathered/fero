import 'package:flutter/material.dart';
import 'initial_sync.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  InitialSyncStatus _status = InitialSyncStatus.notStarted;

  void _refreshStatus() {
    setState(() {
      _status = getInitialSyncStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sync Engine Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Initial Sync Thin Layer')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  runInitialSync('user123', ['featureA', 'featureB']);
                  _refreshStatus();
                  Future.delayed(const Duration(milliseconds: 1200), _refreshStatus);
                },
                child: const Text('Run Initial Sync'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  cancelInitialSync();
                  _refreshStatus();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final has = hasInitialSync('user123', ['featureA']);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('hasInitialSync: $has')));
                },
                child: const Text('Has Initial Sync?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
