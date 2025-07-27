import 'package:logger/logger.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class LoggerService {
  static Logger? _logger;
  static File? _logFile;
  
  static Future<Logger> get instance async {
    if (_logger == null) {
      await _initializeLogger();
    }
    return _logger!;
  }
  
  static Future<void> _initializeLogger() async {
    late Directory appDir;

    if (Platform.isWindows) {
      // On Windows, use LocalAppData
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
    
    // Create the log file path
    final String logFilePath = path.join(appDir.path, 'logs.log');
    _logFile = File(logFilePath);
    
    // Overwrite the log file to start fresh on every app launch
    await _logFile!.writeAsString('');
    
    // Create the logger with file output
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: false, // No colors for file output
        printEmojis: false, // No emojis for file output
        dateTimeFormat: DateTimeFormat.onlyTime,
      ),
      output: MultiOutput([
        ConsoleOutput(), // Still log to console for development
        FileOutput(file: _logFile!),
      ]),
    );
  }
  
  // Convenience methods for direct access (optional)
  static Future<void> debug(String message) async {
    final logger = await instance;
    logger.d(message);
  }
  
  static Future<void> info(String message) async {
    final logger = await instance;
    logger.i(message);
  }
  
  static Future<void> warning(String message) async {
    final logger = await instance;
    logger.w(message);
  }
  
  static Future<void> error(String message, [Object? error, StackTrace? stackTrace]) async {
    final logger = await instance;
    logger.e(message, error: error, stackTrace: stackTrace);
  }
  
  // Get the log file for reading or sharing
  static File? get logFile => _logFile;
  
  // Method to clear logs if needed
  static Future<void> clearLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}

// Custom FileOutput class
class FileOutput extends LogOutput {
  final File file;
  
  FileOutput({required this.file});
  
  @override
  void output(OutputEvent event) {
    // Write each log line to the file
    for (var line in event.lines) {
      file.writeAsStringSync('${DateTime.now().toIso8601String()}: $line\n', 
                           mode: FileMode.append);
    }
  }
}
