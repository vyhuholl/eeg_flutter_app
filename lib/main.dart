import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/eeg_data_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/main_screen.dart';
import 'models/eeg_data.dart';

void main() {
  runApp(const EEGApp());
}

class EEGApp extends StatelessWidget {
  const EEGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // EEG Data Provider
        ChangeNotifierProvider(
          create: (context) => EEGDataProvider(
            config: EEGConfig.defaultConfig(),
          ),
        ),
        
        // Connection Provider (depends on EEG Data Provider)
        ChangeNotifierProxyProvider<EEGDataProvider, ConnectionProvider>(
          create: (context) => ConnectionProvider(
            eegDataProvider: context.read<EEGDataProvider>(),
          ),
          update: (context, eegDataProvider, connectionProvider) {
            return connectionProvider ?? ConnectionProvider(
              eegDataProvider: eegDataProvider,
            );
          },
        ),
      ],
      child: MaterialApp(
        title: 'EEG Monitor',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
