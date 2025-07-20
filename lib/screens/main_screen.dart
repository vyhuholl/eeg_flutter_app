import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/eeg_chart.dart';

/// Main screen of the EEG Flutter app with start screen and EEG chart
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, child) {
        if (connectionProvider.isConnected) {
          return _buildEEGScreen(context);
        } else {
          return _buildStartScreen(context, connectionProvider);
        }
      },
    );
  }

  Widget _buildStartScreen(BuildContext context, ConnectionProvider connectionProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Connect icon from assets
            Image.asset(
              'assets/connect_icon.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 40),
            
            // Connect button
            ElevatedButton(
              onPressed: connectionProvider.isConnecting 
                ? null 
                : () => _connectToDevice(connectionProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: connectionProvider.isConnecting
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Подключение...'),
                    ],
                  )
                : const Text(
                    'Подключить устройство',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEEGScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<EEGDataProvider>(
        builder: (context, eegProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: EEGChart(
              showGridLines: true,
              showAxes: true,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _disconnectFromDevice(),
        backgroundColor: Colors.red,
        child: const Icon(Icons.close, color: Colors.white),
      ),
    );
  }

  void _connectToDevice(ConnectionProvider connectionProvider) {
    connectionProvider.connect(
      address: '0.0.0.0',
      port: 2000,
    );
  }

  void _disconnectFromDevice() {
    final connectionProvider = context.read<ConnectionProvider>();
    connectionProvider.disconnect();
  }
}