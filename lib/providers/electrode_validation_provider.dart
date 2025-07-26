import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/eeg_data.dart';
import '../models/validation_models.dart';
import '../services/validation_data_processor.dart';
import '../providers/eeg_data_provider.dart';
import '../services/logger_service.dart';

/// Provider for managing electrode validation state and process
class ElectrodeValidationProvider extends ChangeNotifier {
  // State management
  ElectrodeValidationState _state = ElectrodeValidationState.initializing;
  ValidationResult? _lastResult;
  
  // Processing components
  final ValidationDataProcessor _processor = ValidationDataProcessor();
  Timer? _validationTimer;
  StreamSubscription<List<EEGJsonSample>>? _dataSubscription;
  
  // Internal tracking
  DateTime? _validationStartTime;
  int _totalSamplesProcessed = 0;
  
  /// Current validation state
  ElectrodeValidationState get state => _state;
  
  /// Last validation result
  ValidationResult? get lastResult => _lastResult;
  
  /// Check if validation is currently active
  bool get isValidating => _dataSubscription != null;
  
  /// Check if validation has been started
  bool get hasStarted => _validationStartTime != null;
  
  /// Get time since validation started
  Duration? get timeSinceStart => _validationStartTime != null 
      ? DateTime.now().difference(_validationStartTime!)
      : null;
  
  /// Total samples processed during validation
  int get totalSamplesProcessed => _totalSamplesProcessed;
  
  /// Start electrode validation process
  Future<void> startValidation(EEGDataProvider eegProvider) async {
    try {
      LoggerService.info('ElectrodeValidationProvider: Starting validation');
      
      // Initialize state
      _validationStartTime = DateTime.now();
      _totalSamplesProcessed = 0;
      _processor.clear();
      _setState(ElectrodeValidationState.initializing);
      
      // Subscribe to EEG data stream
      _dataSubscription = eegProvider.dataProcessor.processedJsonDataStream.listen(
        _onEEGDataReceived,
        onError: _onDataStreamError,
        onDone: _onDataStreamComplete,
      );
      
      // Start validation timer for periodic checks
      _validationTimer = Timer.periodic(
        ValidationConstants.recalculationThrottle,
        _onValidationTimerTick,
      );
      
      // Set initial collecting state after brief delay
      Timer(const Duration(milliseconds: 500), () {
        if (_state == ElectrodeValidationState.initializing) {
          _setState(ElectrodeValidationState.collectingData);
        }
      });
      
      LoggerService.info('ElectrodeValidationProvider: Validation started successfully');
    } catch (e) {
      LoggerService.error('ElectrodeValidationProvider: Failed to start validation: $e');
      _setState(ElectrodeValidationState.connectionLost);
    }
  }
  
  /// Stop electrode validation process
  void stopValidation() {
    LoggerService.info('ElectrodeValidationProvider: Stopping validation');
    
    _dataSubscription?.cancel();
    _dataSubscription = null;
    
    _validationTimer?.cancel();
    _validationTimer = null;
    
    _processor.clear();
    _setState(ElectrodeValidationState.initializing);
    
    LoggerService.info('ElectrodeValidationProvider: Validation stopped');
  }
  
  /// Reset validation state
  void resetValidation() {
    LoggerService.info('ElectrodeValidationProvider: Resetting validation');
    
    stopValidation();
    _lastResult = null;
    _validationStartTime = null;
    _totalSamplesProcessed = 0;
    
    notifyListeners();
  }
  
  /// Handle incoming EEG data samples
  void _onEEGDataReceived(List<EEGJsonSample> samples) {
    if (samples.isEmpty) return;
    
    try {
      // Process each sample
      for (final sample in samples) {
        _processor.addSample(sample.eegValue, sample.absoluteTimestamp);
        _totalSamplesProcessed++;
      }
      
      // Update state based on data availability
      if (_state == ElectrodeValidationState.collectingData && 
          _processor.hasSufficientData) {
        _setState(ElectrodeValidationState.validating);
      }
      
      LoggerService.debug('ElectrodeValidationProvider: Processed ${samples.length} samples, total: $_totalSamplesProcessed');
    } catch (e) {
      LoggerService.error('ElectrodeValidationProvider: Error processing EEG data: $e');
      _setState(ElectrodeValidationState.connectionLost);
    }
  }
  
  /// Handle validation timer ticks for periodic validation
  void _onValidationTimerTick(Timer timer) {
    if (_state == ElectrodeValidationState.validating ||
        _state == ElectrodeValidationState.valid ||
        _state == ElectrodeValidationState.invalid) {
      _performValidation();
    }
  }
  
  /// Perform validation calculation and update state
  void _performValidation() {
    try {
      final result = _processor.calculateValidation();
      _lastResult = result;
      
      // Update state based on validation result
      if (_state != result.state) {
        _setState(result.state);
      }
      
      LoggerService.debug('ElectrodeValidationProvider: Validation result: ${result.state}, valid: ${result.isValid}');
    } catch (e) {
      LoggerService.error('ElectrodeValidationProvider: Error during validation: $e');
      _setState(ElectrodeValidationState.connectionLost);
    }
  }
  
  /// Handle data stream errors
  void _onDataStreamError(dynamic error) {
    LoggerService.error('ElectrodeValidationProvider: Data stream error: $error');
    _setState(ElectrodeValidationState.connectionLost);
  }
  
  /// Handle data stream completion
  void _onDataStreamComplete() {
    LoggerService.warning('ElectrodeValidationProvider: Data stream completed unexpectedly');
    _setState(ElectrodeValidationState.connectionLost);
  }
  
  /// Update state and notify listeners
  void _setState(ElectrodeValidationState newState) {
    if (_state != newState) {
      final oldState = _state;
      _state = newState;
      
      LoggerService.info('ElectrodeValidationProvider: State changed from $oldState to $newState');
      
      // Update result if moving to connection lost
      if (newState == ElectrodeValidationState.connectionLost) {
        _lastResult = ValidationResult.connectionLost();
      } else if (newState == ElectrodeValidationState.insufficientData) {
        _lastResult = ValidationResult.insufficientData();
      }
      
      notifyListeners();
    }
  }
  
  /// Force immediate validation (useful for testing)
  void forceValidation() {
    if (isValidating) {
      _performValidation();
    }
  }
  
  /// Get debug information about validation state
  Map<String, dynamic> getDebugInfo() {
    return {
      'state': _state.toString(),
      'isValidating': isValidating,
      'hasStarted': hasStarted,
      'timeSinceStart': timeSinceStart?.inSeconds,
      'totalSamplesProcessed': _totalSamplesProcessed,
      'lastResult': _lastResult?.toString(),
      'processorInfo': _processor.getDebugInfo(),
    };
  }
  
  @override
  void dispose() {
    LoggerService.info('ElectrodeValidationProvider: Disposing');
    stopValidation();
    super.dispose();
  }
} 