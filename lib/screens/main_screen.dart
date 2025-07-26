import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/eeg_data_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/electrode_validation_provider.dart';
import '../widgets/eeg_chart.dart';
import 'meditation_selection_screen.dart';
import 'electrode_validation_screen.dart';

/// Main screen of the EEG Flutter app with start screen and EEG chart
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, ElectrodeValidationProvider>(
      builder: (context, connectionProvider, validationProvider, child) {
        // Navigation logic based on connection and validation state
        if (!connectionProvider.isConnected) {
          return _buildStartScreen(context, connectionProvider);
        } else if (!validationProvider.isLastValidationSuccessful) {
          return const ElectrodeValidationScreen();
        } else {
          return _buildEEGScreen(context, connectionProvider);
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
            // Instructions text above the connect icon
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'В открывшемся окне нажмите кнопку "Подключить", потом нажмите кнопку "Старт".\nЗатем нажмите здесь "Подключить устройство".',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            
            // Connect icon from assets
            Image.asset(
              'assets/images/connect_icon.png',
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

  Widget _buildEEGScreen(BuildContext context, ConnectionProvider connectionProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<EEGDataProvider>(
        builder: (context, eegProvider, child) {
          final isReceivingData = eegProvider.isReceivingJsonData;
          
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status indicator in top left corner
                  _buildConnectionStatus(isReceivingData),
                  
                  const SizedBox(height: 20),
                  
                  // Centered meditation training button
                  Center(
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () => _startMeditationTraining(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Пройти тренинг медитации',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Instruction text
                        const Text(
                          'Подготовьте музыку для медитации, если она нужна.\nТренинг начнётся сразу',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // EEG Chart (only show if receiving data)
                  if (isReceivingData) ...[
                    Center(
                      child: Column(
                        children: [
                          // EEG Chart with fixed dimensions
                          Container(
                            width: 960,
                            height: 440,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: EEGChart(
                              showGridLines: true,
                              showAxes: true,
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Legend
                          _buildChartLegend(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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

  Widget _buildConnectionStatus(bool isReceivingData) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isReceivingData ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isReceivingData ? 'Электроды подключены' : 'Электроды не подключены',
          style: TextStyle(
            color: isReceivingData ? Colors.green : Colors.red,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegend() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Focus legend item
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 2,
                color: const Color(0xFFBF5AF2), // Violet
              ),
              const SizedBox(width: 6),
              const Text(
                'Фокус',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 20),
          
          // Relaxation legend item
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 2,
                color: const Color(0xFF32D74B), // Green
              ),
              const SizedBox(width: 6),
              const Text(
                'Расслабление',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _connectToDevice(ConnectionProvider connectionProvider) {
    // Reset validation state when starting a new connection
    final validationProvider = context.read<ElectrodeValidationProvider>();
    validationProvider.resetValidation();
    
    connectionProvider.connect(
      address: '0.0.0.0',
      port: 2000,
    );
  }

  void _disconnectFromDevice() {
    final connectionProvider = context.read<ConnectionProvider>();
    final validationProvider = context.read<ElectrodeValidationProvider>();
    
    // Reset validation state when disconnecting
    validationProvider.resetValidation();
    connectionProvider.disconnect();
  }

  void _startMeditationTraining() {
    // Navigate to meditation selection screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MeditationSelectionScreen(),
      ),
    );
  }
}