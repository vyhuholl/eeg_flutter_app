import 'package:flutter/foundation.dart';
import '../models/validation_models.dart';
import '../services/electrode_validation_service.dart';
import 'eeg_data_provider.dart';

/// Provider for managing electrode validation state and operations
class ElectrodeValidationProvider with ChangeNotifier {
  /// Current validation state
  ValidationState _currentState = ValidationState.idle;
  
  /// Most recent validation result
  ValidationResult? _lastValidationResult;
  
  /// Service for performing statistical validation
  final ElectrodeValidationService _validationService = ElectrodeValidationService();
  
  /// Reference to EEG data provider for accessing data
  EEGDataProvider? _eegDataProvider;
  
  /// Whether the provider has been initialized
  bool _isInitialized = false;

  /// Get the current validation state
  ValidationState get currentState => _currentState;
  
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
    
    // Check if we have sufficient data for 5-second validation
    final samples = _eegDataProvider!.dataProcessor.getLatestJsonSamples();
    return samples.length >= ValidationConstants.minSamplesRequired;
  }
  
  /// Initialize the provider with EEG data provider reference
  void initialize(EEGDataProvider eegDataProvider) {
    _eegDataProvider = eegDataProvider;
    _isInitialized = true;
    
    // Set initial state based on data availability
    _updateStateBasedOnDataAvailability();
    notifyListeners();
  }

  /// Start the electrode validation process
  Future<void> startValidation() async {
    if (!_isInitialized) {
      throw StateError('ElectrodeValidationProvider must be initialized before starting validation');
    }
    
    if (_eegDataProvider == null) {
      throw StateError('EEG data provider is not available');
    }
    
    // Check if validation can be started
    if (!canStartValidation) {
      _updateState(ValidationState.insufficientData);
      _lastValidationResult = ValidationResult.insufficientData();
      notifyListeners();
      return;
    }
    
    try {
      // Update state to validating
      _updateState(ValidationState.validating);
      notifyListeners();
      
      // Get the last 5 seconds of EEG data
      final samples = _eegDataProvider!.dataProcessor.getLatestJsonSamples();
      
      // Take only the last 50 seconds worth of data (500 samples at 100Hz)
      final recentSamples = samples.length > ValidationConstants.minSamplesRequired
          ? samples.sublist(samples.length - ValidationConstants.minSamplesRequired)
          : samples;
      
      // Perform validation using the service
      final result = await _validationService.validateElectrodes(recentSamples);
      
      // Update state based on result
      _lastValidationResult = result;
      _updateState(result.state);
      
      notifyListeners();
      
    } catch (e) {
      // Handle errors during validation
      debugPrint('Error during electrode validation: $e');
      _lastValidationResult = ValidationResult.connectionLost();
      _updateState(ValidationState.connectionLost);
      notifyListeners();
    }
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
  
  /// Get debug information for the current validation state
  Map<String, dynamic> getDebugInfo() {
    final Map<String, dynamic> debugInfo = {
      'currentState': _currentState.toString(),
      'hasResult': hasValidationResult,
      'canStart': canStartValidation,
      'isInitialized': _isInitialized,
    };
    
    if (_lastValidationResult != null) {
      debugInfo['lastResult'] = {
        'isValid': _lastValidationResult!.isValid,
        'message': _lastValidationResult!.message,
        'timestamp': _lastValidationResult!.timestamp.toIso8601String(),
        'statistics': {
          'variance': _lastValidationResult!.statistics.variance,
          'minValue': _lastValidationResult!.statistics.minValue,
          'maxValue': _lastValidationResult!.statistics.maxValue,
          'sampleCount': _lastValidationResult!.statistics.sampleCount,
          'validRangeCount': _lastValidationResult!.statistics.validRangeCount,
          'validRangePercentage': _lastValidationResult!.statistics.validRangePercentage,
        },
      };
    }
    
    if (_eegDataProvider != null) {
      final samples = _eegDataProvider!.dataProcessor.getLatestJsonSamples();
      debugInfo['availableSamples'] = samples.length;
      debugInfo['requiredSamples'] = ValidationConstants.minSamplesRequired;
    }
    
    return debugInfo;
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    _eegDataProvider = null;
    super.dispose();
  }
} 