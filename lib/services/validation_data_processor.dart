import 'dart:math' as math;
import '../models/validation_models.dart';
import '../services/logger_service.dart';

/// Data processor for electrode validation using efficient sliding window
class ValidationDataProcessor {
  // Data storage
  final List<double> _eegValues = [];
  final List<DateTime> _timestamps = [];
  
  // Cache management
  bool _statisticsValid = false;
  DateTime? _lastRecalculation;
  
  // Cached results
  double _cachedVariance = 0.0;
  double _cachedMin = double.infinity;
  double _cachedMax = double.negativeInfinity;
  int _cachedSampleCount = 0;
  
  /// Add new EEG sample to the validation window
  void addSample(double eegValue, DateTime timestamp) {
    // Remove expired samples (optimized)
    _removeExpiredSamplesOptimized(timestamp);
    
    // Add new sample
    _eegValues.add(eegValue);
    _timestamps.add(timestamp);
    
    // Invalidate cache
    _statisticsValid = false;
    
    // Maintain maximum buffer size safety (20% buffer beyond 5 seconds)
    if (_eegValues.length > 600) {
      _forceCleanup();
    }
  }

  /// Calculate current validation result
  ValidationResult calculateValidation() {
    if (!_statisticsValid || _shouldRecalculate()) {
      _recalculateStatistics();
    }
    
    // Determine validation state based on results
    ElectrodeValidationState state;
    if (_cachedSampleCount < ValidationConstants.minSamplesRequired) {
      state = ElectrodeValidationState.insufficientData;
    } else {
      final rangeValid = _cachedMin >= ValidationConstants.minEegValue && 
                        _cachedMax <= ValidationConstants.maxEegValue;
      final varianceValid = _cachedVariance <= ValidationConstants.maxVariance;
      
      if (rangeValid && varianceValid) {
        state = ElectrodeValidationState.valid;
      } else {
        state = ElectrodeValidationState.invalid;
      }
    }
    
    return ValidationResult(
      isRangeValid: _cachedMin >= ValidationConstants.minEegValue && 
                   _cachedMax <= ValidationConstants.maxEegValue,
      isVarianceValid: _cachedVariance <= ValidationConstants.maxVariance,
      currentVariance: _cachedVariance,
      sampleCount: _cachedSampleCount,
      minValue: _cachedMin,
      maxValue: _cachedMax,
      state: state,
      timestamp: DateTime.now(),
    );
  }

  /// Get current sample count
  int get sampleCount => _eegValues.length;

  /// Check if we have sufficient data for validation
  bool get hasSufficientData => _eegValues.length >= ValidationConstants.minSamplesRequired;

  /// Clear all validation data
  void clear() {
    _eegValues.clear();
    _timestamps.clear();
    _resetStatistics();
    LoggerService.info('ValidationDataProcessor: Data cleared');
  }

  /// Remove expired samples using optimized approach
  void _removeExpiredSamplesOptimized(DateTime currentTime) {
    final cutoffTime = currentTime.subtract(ValidationConstants.validationWindow);
    
    // Find first valid index
    int removeCount = 0;
    while (removeCount < _timestamps.length && 
           _timestamps[removeCount].isBefore(cutoffTime)) {
      removeCount++;
    }
    
    if (removeCount > 0) {
      _eegValues.removeRange(0, removeCount);
      _timestamps.removeRange(0, removeCount);
      _statisticsValid = false;
      LoggerService.debug('ValidationDataProcessor: Removed $removeCount expired samples');
    }
  }

  /// Check if statistics should be recalculated
  bool _shouldRecalculate() {
    if (_lastRecalculation == null) return true;
    return DateTime.now().difference(_lastRecalculation!) > ValidationConstants.recalculationThrottle;
  }

  /// Recalculate statistics using Welford's algorithm for numerical stability
  void _recalculateStatistics() {
    final now = DateTime.now();
    _lastRecalculation = now;
    
    if (_eegValues.isEmpty) {
      _resetStatistics();
      return;
    }
    
    // Welford's online algorithm for numerical stability
    double mean = 0.0;
    double m2 = 0.0;
    double min = double.infinity;
    double max = double.negativeInfinity;
    
    for (int i = 0; i < _eegValues.length; i++) {
      final value = _eegValues[i];
      
      // Update mean and variance using Welford's algorithm
      final delta = value - mean;
      mean += delta / (i + 1);
      final delta2 = value - mean;
      m2 += delta * delta2;
      
      // Update min/max
      min = math.min(min, value);
      max = math.max(max, value);
    }
    
    // Cache results
    _cachedVariance = _eegValues.length > 1 ? m2 / (_eegValues.length - 1) : 0.0;
    _cachedMin = min;
    _cachedMax = max;
    _cachedSampleCount = _eegValues.length;
    _statisticsValid = true;
    
    LoggerService.debug('ValidationDataProcessor: Statistics recalculated - samples: $_cachedSampleCount, variance: ${_cachedVariance.toStringAsFixed(2)}, range: [${_cachedMin.toStringAsFixed(1)}, ${_cachedMax.toStringAsFixed(1)}]');
  }

  /// Reset cached statistics
  void _resetStatistics() {
    _cachedVariance = 0.0;
    _cachedMin = double.infinity;
    _cachedMax = double.negativeInfinity;
    _cachedSampleCount = 0;
    _statisticsValid = true;
  }

  /// Force cleanup when buffer gets too large
  void _forceCleanup() {
    final targetSize = 500; // Keep last 500 samples
    if (_eegValues.length > targetSize) {
      final removeCount = _eegValues.length - targetSize;
      _eegValues.removeRange(0, removeCount);
      _timestamps.removeRange(0, removeCount);
      _statisticsValid = false;
      LoggerService.warning('ValidationDataProcessor: Force cleanup - removed $removeCount samples');
    }
  }

  /// Get debug information about current state
  Map<String, dynamic> getDebugInfo() {
    return {
      'sampleCount': _eegValues.length,
      'statisticsValid': _statisticsValid,
      'cachedVariance': _cachedVariance,
      'cachedMin': _cachedMin,
      'cachedMax': _cachedMax,
      'lastRecalculation': _lastRecalculation?.toIso8601String(),
      'windowStartTime': _timestamps.isNotEmpty ? _timestamps.first.toIso8601String() : null,
      'windowEndTime': _timestamps.isNotEmpty ? _timestamps.last.toIso8601String() : null,
    };
  }
} 