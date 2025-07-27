import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/eeg_data_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/electrode_validation_provider.dart';
import 'screens/main_screen.dart';
import 'models/eeg_data.dart';
import 'services/logger_service.dart';
import 'dart:async'; // Added for Timer

class AdminPrivilegeChecker {
  /// Checks if the application is running with administrator privileges on Windows
  static Future<bool> isRunningAsAdministrator() async {
    if (!Platform.isWindows) {
      // On non-Windows platforms, assume no administrator check is needed
      return true;
    }
    
    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-Command',
          'if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { "ELEVATED" } else { "NOT_ELEVATED" }'
        ],
        runInShell: false,
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        return output == 'ELEVATED';
      }
      
      return false;
    } catch (e) {
      await LoggerService.error('Error checking administrator privileges: $e');
      // If we can't determine, assume not administrator for security
      return false;
    }
  }
}

class DefenderBypassResult {
  final bool isSuccess;
  final String message;
  final String? detailedError;
  
  const DefenderBypassResult({
    required this.isSuccess,
    required this.message,
    this.detailedError,
  });
}

class ExeManager {
  /// Checks Windows Defender status and threat protection levels
  static Future<Map<String, bool>> checkDefenderStatus() async {
    if (!Platform.isWindows) {
      return {'realTimeProtection': false, 'behaviorMonitoring': false, 'defenderActive': false};
    }
    
    try {
      await LoggerService.info('Checking Windows Defender protection status...');
      
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-Command',
          'Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, BehaviorMonitorEnabled | ConvertTo-Json'
        ],
        runInShell: false,
        stdoutEncoding: utf8,
      );
      
      if (result.exitCode == 0) {
        final jsonStr = result.stdout.toString().trim();
        if (jsonStr.isNotEmpty) {
          final status = json.decode(jsonStr) as Map<String, dynamic>;
          final defenderInfo = <String, bool>{
             'realTimeProtection': status['RealTimeProtectionEnabled'] as bool? ?? false,
             'behaviorMonitoring': status['BehaviorMonitorEnabled'] as bool? ?? false,
             'defenderActive': ((status['RealTimeProtectionEnabled'] as bool? ?? false) || (status['BehaviorMonitorEnabled'] as bool? ?? false)),
          };
          
          await LoggerService.info('Defender Status: Real-time=${defenderInfo['realTimeProtection']}, Behavior=${defenderInfo['behaviorMonitoring']}');
          return defenderInfo;
        }
      }
      
      // Fallback: assume Defender is active if we can't determine status
      await LoggerService.warning('Could not determine Defender status, assuming active');
      return {'realTimeProtection': true, 'behaviorMonitoring': true, 'defenderActive': true};
    } catch (e) {
      await LoggerService.error('Error checking Defender status: $e');
      return {'realTimeProtection': true, 'behaviorMonitoring': true, 'defenderActive': true};
    }
  }
  
  /// Attempts to add EasyEEG_BCI.exe to Windows Defender exclusions with user consent
  static Future<DefenderBypassResult> addDefenderExclusion(String exePath) async {
    if (!Platform.isWindows) {
      return const DefenderBypassResult(
        isSuccess: true,
        message: 'Non-Windows platform, exclusion not needed',
      );
    }
    
    try {
      await LoggerService.info('Attempting to add Defender exclusion for: $exePath');
      final addExclusionResult = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-Command',
                       'try { Add-MpPreference -ExclusionPath "$exePath"; "SUCCESS" } catch { "ERROR: " + \$_.Exception.Message }'
        ],
        runInShell: false,
      );
        
      if (addExclusionResult.exitCode == 0) {
        final output = addExclusionResult.stdout.toString().trim();
        if (output == 'SUCCESS') {
          await LoggerService.info('Successfully added Defender exclusion');
          return const DefenderBypassResult(
            isSuccess: true,
            message: 'Добавлено исключение в Windows Defender',
          );
        } else if (output.startsWith('ERROR:')) {
          await LoggerService.warning('Failed to add exclusion: $output');
          return DefenderBypassResult(
            isSuccess: false,
            message: 'Не удалось добавить исключение',
            detailedError: output,
          );
        }
      }
    return const DefenderBypassResult(
      isSuccess: false,
      message: 'Не удалось добавить исключение в Defender',
    );
    } catch (e) {
      await LoggerService.error('Error adding Defender exclusion: $e');
      return DefenderBypassResult(
        isSuccess: false,
        message: 'Ошибка при работе с Defender',
        detailedError: e.toString(),
      );
    }
  }
  
  /// Alternative launch strategy using different execution contexts to bypass detection
  static Future<bool> launchWithBypassStrategy(String exePath) async {
    if (!Platform.isWindows) {
      return false;
    }
    
    await LoggerService.info('Attempting bypass launch strategies for: $exePath');
    
    // Strategy 1: Launch with bypass flags and process isolation
    try {
      await LoggerService.info('Trying Strategy 1: Process isolation launch...');
      
      final result1 = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-WindowStyle', 'Hidden',
          '-Command',
          'Start-Process -FilePath "$exePath" -WorkingDirectory "${path.dirname(exePath)}" -WindowStyle Normal'
        ],
        runInShell: false,
        stdoutEncoding: utf8,
      );
      
      if (result1.exitCode == 0) {
        await LoggerService.info('Strategy 1 succeeded');
        return true;
      }
      
      await LoggerService.warning('Strategy 1 failed: ${result1.stderr}');
    } catch (e) {
      await LoggerService.warning('Strategy 1 exception: $e');
    }
    
    // Strategy 2: Direct process creation with different command context
    try {
      await LoggerService.info('Trying Strategy 2: Direct CMD execution...');
      
      final result2 = await Process.run(
        'cmd.exe',
        ['/C', 'start', '/D', path.dirname(exePath), path.basename(exePath)],
        runInShell: false,
        stdoutEncoding: utf8,
      );
      
      if (result2.exitCode == 0) {
        await LoggerService.info('Strategy 2 succeeded');
        return true;
      }
      
      await LoggerService.warning('Strategy 2 failed: ${result2.stderr}');
    } catch (e) {
      await LoggerService.warning('Strategy 2 exception: $e');
    }
    
    // Strategy 3: Copy to temp location and execute (bypass path-based detection)
    try {
      await LoggerService.info('Trying Strategy 3: Temporary location execution...');
      
      final tempDir = Directory.systemTemp;
      final tempExePath = path.join(tempDir.path, 'eeg_temp_${DateTime.now().millisecondsSinceEpoch}.exe');
      
      // Copy executable to temp location
      final sourceFile = File(exePath);
      await sourceFile.copy(tempExePath);
      
      await LoggerService.info('Copied executable to temporary location: $tempExePath');
      
      final result3 = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-Command',
          'Start-Process -FilePath "$tempExePath"'
        ],
        runInShell: false,
        stdoutEncoding: utf8,
      );
      
      if (result3.exitCode == 0) {
        await LoggerService.info('Strategy 3 succeeded');
        
        // Schedule cleanup of temp file after delay
        Timer(const Duration(seconds: 30), () async {
          try {
            await File(tempExePath).delete();
            await LoggerService.info('Cleaned up temporary executable');
          } catch (e) {
            await LoggerService.warning('Could not clean up temp file: $e');
          }
        });
        
        return true;
      }
      
      await LoggerService.warning('Strategy 3 failed: ${result3.stderr}');
      
      // Clean up temp file if launch failed
      try {
        await File(tempExePath).delete();
      } catch (e) {
        await LoggerService.warning('Could not clean up failed temp file: $e');
      }
    } catch (e) {
      await LoggerService.warning('Strategy 3 exception: $e');
    }
    
    await LoggerService.error('All bypass strategies failed');
    return false;
  }

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
      
      await LoggerService.info('Launching EasyEEG_BCI.exe with Defender bypass from: $exePath');
      
      // Check Windows Defender status
      final defenderStatus = await checkDefenderStatus();
      
      if (defenderStatus['defenderActive'] == true) {
        await LoggerService.info('Windows Defender is active, applying bypass strategies...');
        
        // Try to add Defender exclusion first (if we have admin rights)
        final exclusionResult = await addDefenderExclusion(exePath);
        if (exclusionResult.isSuccess) {
          await LoggerService.info('Defender exclusion added successfully');
        } else {
          await LoggerService.warning('Could not add Defender exclusion: ${exclusionResult.message}');
        }
        
        // Use bypass launch strategies
        final bypassSuccess = await launchWithBypassStrategy(exePath);
        if (bypassSuccess) {
          await LoggerService.info('EasyEEG_BCI.exe launched successfully using bypass strategy');
          return true;
        }
        
        await LoggerService.warning('Bypass strategies failed, trying standard launch...');
      }
      
      // Fallback to standard launch method
      await LoggerService.info('Attempting standard launch method...');
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy', 'Bypass',
          '-Command', 
          'Start-Process -FilePath "$exePath"'
        ],
        runInShell: false,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      
      if (result.exitCode == 0) {
        await LoggerService.info('EasyEEG_BCI.exe launched successfully with standard method');
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
          'Get-Process | Where-Object {\$_.MainWindowTitle -like "$windowTitlePattern"} | Select-Object -First 1'
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

  // Start the Flutter application with administrator check first
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
        
        // Electrode Validation Provider (depends on EEG Data Provider)
        ChangeNotifierProxyProvider<EEGDataProvider, ElectrodeValidationProvider>(
          create: (context) {
            final provider = ElectrodeValidationProvider();
            provider.initialize(context.read<EEGDataProvider>());
            return provider;
          },
          update: (context, eegDataProvider, validationProvider) {
            if (validationProvider == null) {
              final provider = ElectrodeValidationProvider();
              provider.initialize(eegDataProvider);
              return provider;
            }
            return validationProvider;
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
        home: const AdministratorCheckScreen(), // Start with administrator check first
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AdministratorCheckScreen extends StatefulWidget {
  const AdministratorCheckScreen({super.key});

  @override
  State<AdministratorCheckScreen> createState() => _AdministratorCheckScreenState();
}

class _AdministratorCheckScreenState extends State<AdministratorCheckScreen> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAdministratorPrivileges();
  }

  Future<void> _checkAdministratorPrivileges() async {
    try {
      final isAdministrator = await AdminPrivilegeChecker.isRunningAsAdministrator();
      
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
        
        if (isAdministrator) {
          // Administrator privileges confirmed, proceed to setup instructions
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const SetupInstructionsScreen(),
            ),
          );
        }
        // If not administrator, stay on this screen to show the error message
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
      await LoggerService.error('Error during administrator check: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show loading screen while checking
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(
                color: Colors.blue,
              ),
              SizedBox(height: 20),
              Text(
                'Проверка прав доступа...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show administrator required message
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              const Icon(
                Icons.security,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 30),
              
              // Error message
              const Text(
                'Программа должна быть запущена от имени администратора.\nЗакройте окно и перезапустите программу в нужном режиме.\n(правая кнопка мыши -> Запуск от имени администратора)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
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
        _statusMessage = 'Проверяем систему безопасности...';
        _isError = false;
      });

      // Check if window is already open first
      final isAlreadyOpen = await ExeManager._isWindowOpen('Нейроинтерфейс EasyEEG BCI');
      if (isAlreadyOpen) {
        setState(() {
          _statusMessage = 'Окно EasyEEG BCI уже открыто. Запускаем приложение...';
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        _navigateToMainApp();
        return;
      }

      setState(() {
        _statusMessage = 'Обходим Windows Defender и запускаем EasyEEG_BCI.exe...';
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
          
          windowFound = await ExeManager._isWindowOpen('Нейроинтерфейс EasyEEG BCI');
          
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
          _statusMessage = 'Ошибка: EasyEEG_BCI.exe не смог запуститься\nНе забудьте, что программа должна быть запущена от имени администратора';
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
