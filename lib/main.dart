import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/eeg_data_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/main_screen.dart';
import 'models/eeg_data.dart';
import 'services/logger_service.dart';

class ExeManager {
  /// Creates EasyEEG_BCI.conf file in the current directory with contents from assets
  static Future<bool> createConfigFile() async {
    try {
      // Get the current directory (where the Flutter app executable is located)
      final currentDirectory = Directory.current;
      final configPath = path.join(currentDirectory.path, 'EasyEEG_BCI.conf');
      
      await LoggerService.info('Creating EasyEEG_BCI.conf at: $configPath');
      
      // Read the configuration content from assets
      final configContent = await rootBundle.loadString('assets/EasyEEG_BCI.conf');
      
      // Write the configuration file to the current directory (overwrite if exists)
      final configFile = File(configPath);
      await configFile.writeAsString(configContent);
      
      await LoggerService.info('EasyEEG_BCI.conf created successfully');
      return true;
    } catch (e) {
      await LoggerService.error('Error creating EasyEEG_BCI.conf: $e');
      return false;
    }
  }
  
  static Future<bool> launchExternalApp() async {
    // Only attempt to launch on Windows platform
    if (!Platform.isWindows) {
      await LoggerService.info('EasyEEG_BCI.exe launch skipped: Not Windows platform');
      return true; // Return true for non-Windows to not block app startup
    }
    
    try {
      // First, create the configuration file in the current directory
      final configCreated = await createConfigFile();
      if (!configCreated) {
        await LoggerService.warning('Warning: Failed to create EasyEEG_BCI.conf, but continuing with launch');
        // Continue with launch even if config creation fails
      }
      
      final appDir = Directory.current;
      final exePath = path.join(appDir.path, 'EasyEEG_BCI.exe');
      
      // Verify the executable exists and is accessible
      final exeFile = File(exePath);
      if (!exeFile.existsSync()) {
        await LoggerService.error('Error: EasyEEG_BCI.exe not found at: $exePath');
        return false;
      }
      
      await LoggerService.info('Launching EasyEEG_BCI.exe from: $exePath');
      
      // Launch the executable
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-Command', 
          'Start-Process',
          '-FilePath',
          '"$exePath"'
        ],
        runInShell: false,
      );
      if (result.exitCode == 0) {
        await LoggerService.info('EasyEEG_BCI.exe launched successfully');
        return true;
      } else {
        await LoggerService.error('Error launching EasyEEG_BCI.exe: Exit code ${result.exitCode}');
        if (result.stderr.isNotEmpty) {
          await LoggerService.error('Error output: ${result.stderr}');
        }
        return false;
      }
    } catch (e) {
      await LoggerService.error('Error launching EasyEEG_BCI.exe: $e');
      return false;
    }
  }

  static Future<bool> _isWindowOpen(String windowTitlePattern) async {
    if (!Platform.isWindows) {
      return false; // Not applicable on non-Windows
    }

    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-Command',
          'Get-Process | Where-Object {\$_.MainWindowTitle -like "*$windowTitlePattern*"} | Select-Object -First 1'
        ],
        runInShell: false,
      );

      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        // Check if we actually found a process with a matching window title
        final output = result.stdout.toString().trim();
        // If output contains actual process info (not just headers), window is open
        return output.contains('ProcessName') || output.split('\n').length > 3;
      } else {
        return false;
      }
    } catch (e) {
      await LoggerService.error('Error checking window $windowTitlePattern: $e');
      return false;
    }
  }
}

void main() async {
  // Ensure Flutter binding is initialized for async operations
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger early
  await LoggerService.instance;

  // Start the Flutter application with setup instructions screen
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
        home: const SetupInstructionsScreen(), // Start with setup instructions screen
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SetupInstructionsScreen extends StatelessWidget {
  const SetupInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top text
              const Text(
                'Включите устройство и закрепите его на голове при помощи эластичной ленты, как на картинке:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              // Image
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 400,
                ),
                child: Image.asset(
                  'assets/images/EasyEEGBCI_Headlayout_face.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Изображение недоступно',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              
              // Bottom text
              const Text(
                'Как только будете готовы, нажмите "Продолжить"',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Continue button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const SplashScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Продолжить',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
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
        _statusMessage = 'Создаём файл конфигурации...';
        _isError = false;
      });

      // Check if window is already open first
      final isAlreadyOpen = await ExeManager._isWindowOpen('EasyEEG BCI');
      if (isAlreadyOpen) {
        setState(() {
          _statusMessage = 'Окно EasyEEG BCI уже открыто. Запускаем приложение...';
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
          _statusMessage = 'Ожидаем открытия окна EasyEEG BCI...';
        });
        
        // Poll every 5000 milliseconds until window is found
        bool windowFound = false;
        int attempts = 0;
        
        while (!windowFound) {
          attempts++;
          
          setState(() {
            _statusMessage = 'Ожидаем открытия окна EasyEEG BCI... (попытка $attempts)';
          });
          
          // Wait 5000 milliseconds before checking
          await Future.delayed(const Duration(milliseconds: 5000));
          
          windowFound = await ExeManager._isWindowOpen('EasyEEG BCI');
          
          if (windowFound) {
            setState(() {
              _statusMessage = 'Окно EasyEEG BCI найдено. Запускаем приложение...';
            });
            await Future.delayed(const Duration(milliseconds: 1000));
            _navigateToMainApp();
            break;
          }
          
          // Optional: Add a maximum number of attempts to prevent infinite loop in case of issues
          // You can remove this if you want truly indefinite polling
          if (attempts > 120) { // 120 attempts = 10 minutes of waiting
            setState(() {
              _statusMessage = 'Таймаут: Окно EasyEEG BCI не найдено после 10 минут ожидания';
              _isError = true;
            });
            break;
          }
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
      await LoggerService.error('Error during external app launch: $e');
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
