import 'dart:io';
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
      return false;
    }
  }

  static Future<bool> _isProcessRunning(String processName) async {
    if (!Platform.isWindows) {
      return false; // Not applicable on non-Windows
    }

    try {
      final result = await Process.run(
        'powershell.exe',
        ['-Command', 'Get-Process', '-Name', processName],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error checking process $processName: $e');
      return false;
    }
  }
}

void main() async {
  // Ensure Flutter binding is initialized for async operations
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the Flutter application with splash screen
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
        home: const SplashScreen(), // Start with splash screen
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Запускаем приложение...';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _launchExternalAppAndNavigate();
  }

  Future<void> _launchExternalAppAndNavigate() async {
    try {
      setState(() {
        _statusMessage = 'Ищем EasyEEG_BCI.exe...';
        _isError = false;
      });

      // Check if already running first
      final isAlreadyRunning = await ExeManager._isProcessRunning('EasyEEG_BCI');
      if (isAlreadyRunning) {
        setState(() {
          _statusMessage = 'EasyEEG_BCI.exe уже запущен. Запускаем приложение...';
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        _navigateToMainApp();
        return;
      }

      setState(() {
        _statusMessage = 'Извлекаем EasyEEG_BCI.exe...';
      });

      final launched = await ExeManager.launchExternalApp();
      
      if (launched) {
        setState(() {
          _statusMessage = 'Проверяем, что EasyEEG_BCI.exe запущен...';
        });
        
        // Wait a bit longer and verify the process is actually running
        await Future.delayed(const Duration(milliseconds: 2000));
        
        final isRunning = await ExeManager._isProcessRunning('EasyEEG_BCI');
        if (isRunning) {
          setState(() {
            _statusMessage = 'EasyEEG_BCI.exe запущен. Запускаем приложение...';
          });
          await Future.delayed(const Duration(milliseconds: 1000));
          _navigateToMainApp();
        } else {
          setState(() {
            _statusMessage = 'Ошибка: EasyEEG_BCI.exe не смог запуститься';
            _isError = true;
          });
        }
      } else {
        setState(() {
          _statusMessage = 'Ошибка: EasyEEG_BCI.exe не смог запуститься';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка во время запуска: $e';
        _isError = true;
      });
      debugPrint('Error during external app launch: $e');
    }
  }

  void _navigateToMainApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainScreen(),
      ),
    );
  }

  void _retryLaunch() {
    setState(() {
      _statusMessage = 'Пробуем запустить ещё раз...';
      _isError = false;
    });
    _launchExternalAppAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // EEG Icon or Logo
            Icon(
              Icons.psychology,
              size: 80,
              color: _isError ? Colors.red : Colors.blue,
            ),
            const SizedBox(height: 30),
            
            // Title
            const Text(
              'EEG Monitor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Status message
            Text(
              _statusMessage,
              style: TextStyle(
                color: _isError ? Colors.red : Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // Loading indicator or retry button
            if (!_isError) ...[
              const CircularProgressIndicator(
                color: Colors.blue,
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _retryLaunch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Попробовать ещё раз'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _navigateToMainApp,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text('Продолжить без EasyEEG_BCI.exe'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
