import '../models/eeg_data.dart';
import '../models/validation_models.dart';

/// Service for performing electrode validation using statistical analysis
class ElectrodeValidationService {
  /// Validate electrode connection quality using EEG data samples
  /// 
  /// Analyzes the last 10 seconds of EEG data to check:
  /// - All eegValue readings are between 500-2000
  /// - Variance of eegValue is less than 500
  /// 
  /// Returns [ValidationResult] with success/failure and detailed statistics
  Future<ValidationResult> validateElectrodes(List<EEGJsonSample> samples) async {
    if (samples.isEmpty) {
      return ValidationResult.insufficientData();
    }
    
    if (samples.length < ValidationConstants.minSamplesRequired) {
      return ValidationResult.insufficientData();
    }
    
    try {
      // Extract eegValue from all samples
      final eegValues = samples.map((sample) => sample.eegValue).toList();
      
      // Calculate statistics using Welford's algorithm for numerical stability
      final statistics = _calculateStatistics(eegValues);
      
      // Check validation criteria
      final rangeValid = _validateRange(statistics);
      final varianceValid = _validateVariance(statistics);
      
      // Determine overall validation result
      if (rangeValid && varianceValid) {
        return ValidationResult.success(statistics: statistics);
      } else if (!rangeValid) {
        return ValidationResult.rangeFailure(statistics: statistics);
      } else {
        return ValidationResult.varianceFailure(statistics: statistics);
      }
      
    } catch (e) {
      // Handle any errors during validation
      return ValidationResult.connectionLost();
    }
  }
  
  /// Calculate comprehensive statistics for EEG values using Welford's algorithm
  ValidationStatistics _calculateStatistics(List<double> values) {
    if (values.isEmpty) {
      return ValidationStatistics.empty();
    }
    
    // Initialize values
    double minVal = values.first;
    double maxVal = values.first;
    int validRangeCount = 0;
    
    // Calculate min, max, and valid range count in single pass
    for (final value in values) {
      if (value < minVal) minVal = value;
      if (value > maxVal) maxVal = value;
      if (ValidationConstants.isValueInRange(value)) {
        validRangeCount++;
      }
    }
    
    // Calculate variance using Welford's online algorithm for numerical stability
    double variance = 0.0;
    if (values.length > 1) {
      double mean = 0.0;
      double m2 = 0.0;
      
      for (int i = 0; i < values.length; i++) {
        final delta = values[i] - mean;
        mean += delta / (i + 1);
        final delta2 = values[i] - mean;
        m2 += delta * delta2;
      }
      
      // Sample variance (unbiased estimator)
      variance = m2 / (values.length - 1);
    }
    
    return ValidationStatistics(
      variance: variance,
      minValue: minVal,
      maxValue: maxVal,
      sampleCount: values.length,
      validRangeCount: validRangeCount,
    );
  }
  
  /// Validate that all EEG values are within the valid range (500-2000)
  bool _validateRange(ValidationStatistics statistics) {
    // All values must be within the valid range
    return statistics.validRangeCount == statistics.sampleCount;
  }
  
  /// Validate that the variance is within acceptable limits (<500)
  bool _validateVariance(ValidationStatistics statistics) {
    return ValidationConstants.isVarianceValid(statistics.variance);
  }
  
  /// Get the last N seconds of data from a list of samples
  /// 
  /// [samples] - All available EEG samples
  /// [seconds] - Number of seconds to extract (default: 10)
  /// [sampleRate] - Sample rate in Hz (default: 100)
  List<EEGJsonSample> getLastNSeconds(
    List<EEGJsonSample> samples, {
    int seconds = ValidationConstants.validationWindowSeconds,
    int sampleRate = ValidationConstants.sampleRateHz,
  }) {
    final requiredSamples = seconds * sampleRate;
    
    if (samples.length <= requiredSamples) {
      return samples;
    }
    
    return samples.sublist(samples.length - requiredSamples);
  }
  
  /// Check if sufficient data is available for validation
  /// 
  /// [samples] - Available EEG samples
  /// Returns true if enough data is available for 10-second validation
  bool hasSufficientData(List<EEGJsonSample> samples) {
    return samples.length >= ValidationConstants.minSamplesRequired;
  }
  
  /// Calculate statistical summary for debug purposes
  /// 
  /// Returns a map with statistical information suitable for debugging
  Map<String, dynamic> calculateDebugStatistics(List<EEGJsonSample> samples) {
    if (samples.isEmpty) {
      return {
        'sampleCount': 0,
        'hasSufficientData': false,
        'error': 'No samples available',
      };
    }
    
    final eegValues = samples.map((sample) => sample.eegValue).toList();
    final statistics = _calculateStatistics(eegValues);
    
    return {
      'sampleCount': statistics.sampleCount,
      'hasSufficientData': hasSufficientData(samples),
      'variance': statistics.variance,
      'standardDeviation': statistics.standardDeviation,
      'minValue': statistics.minValue,
      'maxValue': statistics.maxValue,
      'validRangeCount': statistics.validRangeCount,
      'validRangePercentage': statistics.validRangePercentage,
      'rangeValid': _validateRange(statistics),
      'varianceValid': _validateVariance(statistics),
      'overallValid': _validateRange(statistics) && _validateVariance(statistics),
      'validationCriteria': {
        'minValidValue': ValidationConstants.minValidEegValue,
        'maxValidValue': ValidationConstants.maxValidEegValue,
        'maxAllowedVariance': ValidationConstants.maxAllowedVariance,
        'requiredSamples': ValidationConstants.minSamplesRequired,
      },
    };
  }
} 