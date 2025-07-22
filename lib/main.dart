import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/eeg_data_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/main_screen.dart';
import 'models/eeg_data.dart';

class ExeManager {
  static Future<String> extractAndGetExePath() async {
    // Use local app data directory for executables on Windows
    late Directory appDir;
    
    if (Platform.isWindows) {
      // On Windows, use LocalAppData for better executable permissions
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        appDir = Directory(path.join(localAppData, 'eeg_flutter_app'));
      } else {
        // Fallback to application support directory
        appDir = await getApplicationSupportDirectory();
      }
    } else {
      // For other platforms, use application support directory
      appDir = await getApplicationSupportDirectory();
    }
    
    // Ensure directory exists
    if (!appDir.existsSync()) {
      await appDir.create(recursive: true);
    }
    
    final exePath = path.join(appDir.path, 'EasyEEG_BCI.exe');
    final confPath = path.join(appDir.path, 'EasyEEG_BCI.conf');

    // Check if already extracted and up to date
    if (File(exePath).existsSync()) {
      debugPrint('EasyEEG_BCI.exe already exists at: $exePath');
      return exePath;
    }
    
    try {
      debugPrint('Extracting EasyEEG_BCI.exe to: $exePath');
      
      // Extract executable from assets
      final byteData = await rootBundle.load('assets/EasyEEG_BCI.exe');
      final bytes = byteData.buffer.asUint8List();
      
      // Write to app directory
      await File(exePath).writeAsBytes(bytes);
      debugPrint('EasyEEG_BCI.exe extracted successfully');

      // Copy configuration file
      final confByteData = kDebugMode 
          ? await rootBundle.load('assets/EasyEEG_BCI_debug.conf')
          : await rootBundle.load('assets/EasyEEG_BCI.conf');

      final confBytes = confByteData.buffer.asUint8List();
      await File(confPath).writeAsBytes(confBytes);
      debugPrint('Configuration file extracted: ${kDebugMode ? 'debug' : 'release'} mode');

      return exePath;
    } catch (e) {
      debugPrint('Error extracting EasyEEG_BCI.exe: $e');
      rethrow;
    }
  }
  
  static Future<bool> launchExternalApp() async {
    // Only attempt to launch on Windows platform
    if (!Platform.isWindows) {
      debugPrint('EasyEEG_BCI.exe launch skipped: Not Windows platform');
      return true; // Return true for non-Windows to not block app startup
    }
    
    try {
      final exePath = await extractAndGetExePath();
      
      // Verify the executable exists and is accessible
      final exeFile = File(exePath);
      if (!exeFile.existsSync()) {
        debugPrint('Error: EasyEEG_BCI.exe not found at: $exePath');
        return false;
      }
      
      debugPrint('Launching EasyEEG_BCI.exe from: $exePath');
      
      // Launch the executable using Windows Start-Process (proper method for GUI apps)
      // This is equivalent to PowerShell's Start-Process command
      final result = await Process.run(
        'powershell.exe',
        ['-Command', 'Start-Process', '-FilePath', '"$exePath"'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        debugPrint('EasyEEG_BCI.exe launched successfully');
        return true;
      } else {
        debugPrint('Error launching EasyEEG_BCI.exe: Exit code ${result.exitCode}');
        if (result.stderr.isNotEmpty) {
          debugPrint('Error output: ${result.stderr}');
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error launching EasyEEG_BCI.exe: $e');
      // Don't block app startup even if external app fails to launch
      return false;
    }
  }
}

void main() async {
  // Ensure Flutter binding is initialized for async operations
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint('Attempting to launch EasyEEG_BCI.exe...');
    final launched = await ExeManager.launchExternalApp();
    
    if (launched) {
      debugPrint('EasyEEG_BCI.exe launched successfully, starting Flutter app');
    } else {
      debugPrint('EasyEEG_BCI.exe launch failed, continuing with Flutter app');
    }
  } catch (e) {
    debugPrint('Error during external app launch: $e');
    debugPrint('Continuing with Flutter app startup');
  }
  
  // Start the Flutter application
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
