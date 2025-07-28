import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/validation_models.dart';
import '../services/electrode_validation_isolate.dart';
import 'eeg_data_provider.dart';

/// Provider for managing electrode validation state and operations
class ElectrodeValidationProvider with ChangeNotifier {
  /// Current validation state
  ValidationState _currentState = ValidationState.idle;
  
  /// Most recent validation result
  ValidationResult? _lastValidationResult;
  
  /// Background isolate service for continuous validation
  final ElectrodeValidationIsolateService _isolateService = ElectrodeValidationIsolateService();
  
  /// Reference to EEG data provider for accessing data
  EEGDataProvider? _eegDataProvider;
  
    /// Whether the provider has been initialized
  bool _isInitialized = false;

  /// Timer for feeding data to the isolate
  Timer? _dataFeedTimer;

  /// Subscription to isolate validation results
  StreamSubscription<ElectrodeValidationResult>? _validationSubscription;

  /// Get the current validation state
  ValidationState get currentState => _currentState;
  
  /// Whether the provider has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Get the last validation result (may be null)
  ValidationResult? get lastValidationResult => _lastValidationResult;
  
  /// Whether validation has ever been performed
  bool get hasValidationResult => _lastValidationResult != null;
  
  /// Whether the last validation was successful
  bool get isLastValidationSuccessful => _lastValidationResult?.isValid ?? false;
  
  /// Whether validation is currently in progress
  bool get isValidating => _currentState.isProcessing;
  
  /// Whether validation can be started (sufficient data available)
  bool get canStartValidation {
    if (_eegDataProvider == null) return false;
    
    // Check if we have sufficient data for 10-second validation
    final samples = _eegDataProvider!.dataProcessor.getLatestJsonSamples();
    return samples.length >= ValidationConstants.minSamplesRequired;
  }
  
  /// Initialize the provider with EEG data provider reference
  void initialize(EEGDataProvider eegDataProvider) {
    _eegDataProvider = eegDataProvider;
    _isInitialized = true;
    
    // Start continuous validation
    _startContinuousValidation();
    
    // Set initial state based on data availability
    _updateStateBasedOnDataAvailability();
    notifyListeners();
  }
  
  /// Reset validation state to idle
  void resetValidation() {
    _updateState(ValidationState.idle);
    _lastValidationResult = null;
    notifyListeners();
  }
  
  /// Check data availability and update state accordingly
  void checkDataAvailability() {
    if (!_isInitialized) return;
    
    _updateStateBasedOnDataAvailability();
    notifyListeners();
  }
  
  /// Update the current state based on data availability
  void _updateStateBasedOnDataAvailability() {
    if (_eegDataProvider == null) {
      _updateState(ValidationState.connectionLost);
      return;
    }
    
    // Only update state if currently idle or collecting data
    if (_currentState == ValidationState.idle || _currentState == ValidationState.collectingData) {
      if (canStartValidation) {
        _updateState(ValidationState.idle);
      } else {
        _updateState(ValidationState.collectingData);
      }
    }
  }
  
  /// Update the current state
  void _updateState(ValidationState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      debugPrint('Electrode validation state changed to: $newState');
    }
  }

  /// Start continuous validation using background isolate
  Future<void> _startContinuousValidation() async {
    try {
      // Start the isolate
      await _isolateService.start();
      
      // Listen to validation results
      _validationSubscription = _isolateService.resultStream?.listen((result) {
        debugPrint('ElectrodeValidation: Received result - valid: ${result.isValid}, status: ${result.status}');
        
        // Convert isolate result to validation result
        _lastValidationResult = ValidationResult(
          isValid: result.isValid,
          state: result.isValid ? ValidationState.validationPassed : ValidationState.validationFailed,
          message: result.status,
          statistics: ValidationStatistics(
            variance: result.variance,
            minValue: result.minValue.toInt(),
            maxValue: result.maxValue.toInt(),
            sampleCount: 100, // 1 second at 100Hz
            validRangeCount: result.isValid ? 100 : 0,
          ),
          timestamp: result.timestamp,
        );
        
        _updateState(_lastValidationResult!.state);
        notifyListeners();
      });
      
      // Start timer to feed data to isolate
      _dataFeedTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_eegDataProvider != null) {
          final samples = _eegDataProvider!.dataProcessor.getLatestJsonSamples();
          if (samples.isNotEmpty) {
            debugPrint('ElectrodeValidation: Feeding ${samples.length} samples to isolate');
            _isolateService.addEEGData(samples);
          } else {
            debugPrint('ElectrodeValidation: No samples available to feed');
          }
        } else {
          debugPrint('ElectrodeValidation: EEG data provider is null');
        }
      });
      
    } catch (e) {
      debugPrint('Error starting continuous validation: $e');
    }
  }

  /// Stop continuous validation
  void _stopContinuousValidation() {
    _dataFeedTimer?.cancel();
    _dataFeedTimer = null;
    _validationSubscription?.cancel();
    _validationSubscription = null;
    _isolateService.stop();
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    _stopContinuousValidation();
    _eegDataProvider = null;
    _isolateService.dispose();
    super.dispose();
  }
} 