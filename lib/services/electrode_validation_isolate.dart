import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/eeg_data.dart';

/// Message types for communication between main thread and validation isolate
enum ValidationMessageType {
  newData,
  result,
  stop,
}

/// Message structure for isolate communication
class ValidationMessage {
  final ValidationMessageType type;
  final dynamic data;

  const ValidationMessage({
    required this.type,
    required this.data,
  });
}

/// Electrode validation result
class ElectrodeValidationResult {
  final bool isValid;
  final String status;
  final int minValue;
  final int maxValue;
  final double variance;
  final DateTime timestamp;

  const ElectrodeValidationResult({
    required this.isValid,
    required this.status,
    required this.minValue,
    required this.maxValue,
    required this.variance,
    required this.timestamp,
  });

  /// Check if electrode contact is valid based on criteria
  static ElectrodeValidationResult fromEEGValues(List<int> eegValues) {
    if (eegValues.isEmpty) {
      return ElectrodeValidationResult(
        isValid: false,
        status: 'Проблемы с контактом электродов',
        minValue: 0,
        maxValue: 0,
        variance: 0,
        timestamp: DateTime.now(),
      );
    }

    final minValue = eegValues.reduce(min);
    final maxValue = eegValues.reduce(max);
    final variance = _calculateVariance(eegValues);

    // Validation criteria:
    // - min eegValue >= 500
    // - max eegValue <= 3000
    // - variance <= 500
    final bool isValid = minValue >= 500 && maxValue <= 3000 && variance <= 500;

    return ElectrodeValidationResult(
      isValid: isValid,
      status: isValid ? 'Электроды подключены' : 'Проблемы с контактом электродов',
      minValue: minValue,
      maxValue: maxValue,
      variance: variance,
      timestamp: DateTime.now(),
    );
  }

  /// Calculate variance of EEG values using Welford's algorithm
  static double _calculateVariance(List<int> values) {
    if (values.length < 2) return 0.0;

    double mean = 0.0;
    double m2 = 0.0;

    for (int i = 0; i < values.length; i++) {
      final delta = values[i] - mean;
      mean += delta / (i + 1);
      final delta2 = values[i] - mean;
      m2 += delta * delta2;
    }

    // Sample variance (unbiased estimator)
    return m2 / (values.length - 1);
  }
}

/// Background electrode validation service using isolates
class ElectrodeValidationIsolateService {
  Isolate? _isolate;
  SendPort? _sendPort;
  late ReceivePort _receivePort;
  StreamController<ElectrodeValidationResult>? _resultController;

  /// Stream of validation results
  Stream<ElectrodeValidationResult>? get resultStream => _resultController?.stream;

  /// Start the background validation isolate
  Future<void> start() async {
    if (_isolate != null) return; // Already started

    _receivePort = ReceivePort();
    _resultController = StreamController<ElectrodeValidationResult>.broadcast();

    try {
      _isolate = await Isolate.spawn(
        _validationIsolateEntry,
        _receivePort.sendPort,
      );

      // Listen for messages from isolate
      _receivePort.listen((message) {
        if (message is ValidationMessage) {
          switch (message.type) {
            case ValidationMessageType.result:
              if (message.data is ElectrodeValidationResult) {
                _resultController?.add(message.data);
              }
              break;
            default:
              break;
          }
        } else if (message is SendPort) {
          _sendPort = message;
        }
      });

      // Wait for isolate to send its SendPort
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('Error starting validation isolate: $e');
      _cleanup();
    }
  }

  /// Add new EEG data for validation
  void addEEGData(List<EEGJsonSample> samples) {
    if (_sendPort == null || samples.isEmpty) {
      debugPrint('ElectrodeValidation: Cannot send data - sendPort: ${_sendPort != null}, samples: ${samples.length}');
      return;
    }

    // Extract eegValue from last 1 second of data (100 samples at 100Hz)
    final recentSamples = samples.length > 100 
        ? samples.sublist(samples.length - 100)
        : samples;

    final eegValues = recentSamples.map((sample) => sample.eegValue).toList();

    debugPrint('ElectrodeValidation: Sending ${eegValues.length} samples to isolate');
    _sendPort?.send(ValidationMessage(
      type: ValidationMessageType.newData,
      data: eegValues,
    ));
  }

  /// Stop the validation isolate
  Future<void> stop() async {
    if (_isolate == null) return;

    _sendPort?.send(const ValidationMessage(
      type: ValidationMessageType.stop,
      data: null,
    ));

    _cleanup();
  }

  void _cleanup() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort.close();
    _resultController?.close();
    _resultController = null;
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

/// Entry point for the validation isolate
void _validationIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  // Timer for periodic validation (every 100ms)
  Timer? validationTimer;
  List<int> currentEEGValues = [];

  validationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
    if (currentEEGValues.isNotEmpty) {
      // Perform validation on current data
      final result = ElectrodeValidationResult.fromEEGValues(currentEEGValues);
      
      // Send result back to main thread
      mainSendPort.send(ValidationMessage(
        type: ValidationMessageType.result,
        data: result,
      ));
    }
  });

  receivePort.listen((message) {
    if (message is ValidationMessage) {
      switch (message.type) {
        case ValidationMessageType.newData:
          if (message.data is List<int>) {
            currentEEGValues = List<int>.from(message.data);
          }
          break;
        case ValidationMessageType.stop:
          validationTimer?.cancel();
          receivePort.close();
          break;
        default:
          break;
      }
    }
  });
} 