import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Enumeration of possible validation states for UI state management
enum ValidationState {
  /// Initial state before validation starts
  idle,
  /// Currently collecting data for validation
  collectingData,
  /// Performing validation analysis
  validating,
  /// Validation completed successfully
  validationPassed,
  /// Validation failed due to invalid electrode contact
  validationFailed,
  /// Insufficient data available for validation
  insufficientData,
  /// Connection lost during validation
  connectionLost,
}

/// Extension to provide human-readable Russian descriptions for validation states
extension ValidationStateExtension on ValidationState {
  /// Get the Russian localized display text for this validation state
  String get displayText {
    switch (this) {
      case ValidationState.idle:
        return 'Готов к проверке электродов';
      case ValidationState.collectingData:
        return 'Сбор данных... Подождите 10 секунд';
      case ValidationState.validating:
        return 'Проверка качества соединения...';
      case ValidationState.validationPassed:
        return 'Электроды подключены правильно';
      case ValidationState.validationFailed:
        return 'Проблемы с контактом электродов';
      case ValidationState.insufficientData:
        return 'Недостаточно данных для проверки';
      case ValidationState.connectionLost:
        return 'Соединение потеряно. Переподключите устройство';
    }
  }

  /// Get the color associated with this validation state
  Color get color {
    switch (this) {
      case ValidationState.idle:
      case ValidationState.collectingData:
      case ValidationState.validating:
        return const Color(0xFFFFFFFF); // White for process states
      case ValidationState.validationPassed:
        return const Color(0xFF32D74B); // Green for success
      case ValidationState.validationFailed:
      case ValidationState.insufficientData:
      case ValidationState.connectionLost:
        return const Color(0xFFFF3B30); // Red for error states
    }
  }

  /// Check if this state represents a successful validation
  bool get isSuccess => this == ValidationState.validationPassed;

  /// Check if this state represents an error condition
  bool get isError => [
        ValidationState.validationFailed,
        ValidationState.insufficientData,
        ValidationState.connectionLost,
      ].contains(this);

  /// Check if validation is currently in progress
  bool get isProcessing => [
        ValidationState.collectingData,
        ValidationState.validating,
      ].contains(this);
}

/// Statistical data from electrode validation analysis
class ValidationStatistics {
  /// Variance of EEG values over the analysis window
  final double variance;
  
  /// Minimum EEG value found in the analysis window
  final double minValue;
  
  /// Maximum EEG value found in the analysis window
  final double maxValue;
  
  /// Total number of samples analyzed
  final int sampleCount;
  
  /// Number of samples within the valid range (500-2000)
  final int validRangeCount;
  
  /// Percentage of samples within valid range
  double get validRangePercentage => sampleCount > 0 ? (validRangeCount / sampleCount) * 100 : 0;
  
  /// Standard deviation (square root of variance)
  double get standardDeviation => variance > 0 ? math.sqrt(variance) : 0;

  const ValidationStatistics({
    required this.variance,
    required this.minValue,
    required this.maxValue,
    required this.sampleCount,
    required this.validRangeCount,
  });

  /// Create ValidationStatistics with no data
  factory ValidationStatistics.empty() {
    return const ValidationStatistics(
      variance: 0,
      minValue: 0,
      maxValue: 0,
      sampleCount: 0,
      validRangeCount: 0,
    );
  }

  /// Create a copy of this object with updated values
  ValidationStatistics copyWith({
    double? variance,
    double? minValue,
    double? maxValue,
    int? sampleCount,
    int? validRangeCount,
  }) {
    return ValidationStatistics(
      variance: variance ?? this.variance,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      sampleCount: sampleCount ?? this.sampleCount,
      validRangeCount: validRangeCount ?? this.validRangeCount,
    );
  }

  @override
  String toString() {
    return 'ValidationStatistics('
        'variance: ${variance.toStringAsFixed(2)}, '
        'minValue: ${minValue.toStringAsFixed(2)}, '
        'maxValue: ${maxValue.toStringAsFixed(2)}, '
        'sampleCount: $sampleCount, '
        'validRangeCount: $validRangeCount, '
        'validRangePercentage: ${validRangePercentage.toStringAsFixed(1)}%)';
  }
}

/// Result of electrode validation process
class ValidationResult {
  /// Whether the validation passed or failed
  final bool isValid;
  
  /// The current validation state
  final ValidationState state;
  
  /// Human-readable message describing the result
  final String message;
  
  /// Detailed statistical information from the validation
  final ValidationStatistics statistics;
  
  /// Timestamp when this result was created
  final DateTime timestamp;

  const ValidationResult({
    required this.isValid,
    required this.state,
    required this.message,
    required this.statistics,
    required this.timestamp,
  });

  /// Create a successful validation result
  factory ValidationResult.success({
    required ValidationStatistics statistics,
    String? customMessage,
  }) {
    return ValidationResult(
      isValid: true,
      state: ValidationState.validationPassed,
      message: customMessage ?? 'Электроды подключены правильно. Качество сигнала хорошее.',
      statistics: statistics,
      timestamp: DateTime.now(),
    );
  }

  /// Create a failed validation result due to range issues
  factory ValidationResult.rangeFailure({
    required ValidationStatistics statistics,
  }) {
    return ValidationResult(
      isValid: false,
      state: ValidationState.validationFailed,
      message: 'Проблемы с контактом электродов.\n'
          'Убедитесь, что между кожей и электродами нет волос. Затем нажмите "Проверить электроды" ещё раз.\n'
          'Если проблема продолжается, попробуйте аккуратно поправить один из электродов либо же смочить контакты водой.',
      statistics: statistics,
      timestamp: DateTime.now(),
    );
  }

  /// Create a failed validation result due to high variance
  factory ValidationResult.varianceFailure({
    required ValidationStatistics statistics,
  }) {
    return ValidationResult(
      isValid: false,
      state: ValidationState.validationFailed,
      message: 'Проблемы с контактом электродов.\n'
          'Убедитесь, что между кожей и электродами нет волос.\n'
          'Затем нажмите "Проверить электроды" ещё раз.\n'
          'Если проблема продолжается, попробуйте аккуратно поправить один из электродов\n'
          'либо же смочить контакты водой.',
      statistics: statistics,
      timestamp: DateTime.now(),
    );
  }

  /// Create a result for insufficient data
  factory ValidationResult.insufficientData() {
    return ValidationResult(
      isValid: false,
      state: ValidationState.insufficientData,
      message: 'Недостаточно данных для проверки.\n'
          'Подождите пока накопится достаточно данных (10 секунд).',
      statistics: ValidationStatistics.empty(),
      timestamp: DateTime.now(),
    );
  }

  /// Create a result for connection lost
  factory ValidationResult.connectionLost() {
    return ValidationResult(
      isValid: false,
      state: ValidationState.connectionLost,
      message: 'Соединение потеряно.\n'
          'Переподключите устройство и попробуйте снова.',
      statistics: ValidationStatistics.empty(),
      timestamp: DateTime.now(),
    );
  }

  /// Create a copy of this result with updated values
  ValidationResult copyWith({
    bool? isValid,
    ValidationState? state,
    String? message,
    ValidationStatistics? statistics,
    DateTime? timestamp,
  }) {
    return ValidationResult(
      isValid: isValid ?? this.isValid,
      state: state ?? this.state,
      message: message ?? this.message,
      statistics: statistics ?? this.statistics,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'ValidationResult('
        'isValid: $isValid, '
        'state: $state, '
        'message: $message, '
        'statistics: $statistics, '
        'timestamp: $timestamp)';
  }
}

/// Constants used in electrode validation
class ValidationConstants {
  /// Minimum valid EEG value (inclusive)
  static const double minValidEegValue = 500.0;
  
  /// Maximum valid EEG value (inclusive)
  static const double maxValidEegValue = 3000.0;
  
  /// Maximum allowed variance for valid electrode contact
  static const double maxAllowedVariance = 500.0;
  
  /// Required time window for validation in seconds
  static const int validationWindowSeconds = 10;
  
  /// Minimum number of samples required for validation (at 100Hz)
  static const int minSamplesRequired = validationWindowSeconds * 100;
  
  /// Sample rate in Hz (samples per second)
  static const int sampleRateHz = 100;

  /// Check if an EEG value is within the valid range
  static bool isValueInRange(double value) {
    return value >= minValidEegValue && value <= maxValidEegValue;
  }

  /// Check if variance is within acceptable limits
  static bool isVarianceValid(double variance) {
    return variance < maxAllowedVariance;
  }
} 