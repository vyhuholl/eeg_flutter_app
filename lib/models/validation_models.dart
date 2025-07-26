

/// Validation constants for electrode connection quality
class ValidationConstants {
  static const double minEegValue = 500.0;
  static const double maxEegValue = 2000.0;
  static const double maxVariance = 500.0;
  static const Duration validationWindow = Duration(seconds: 5);
  static const Duration recalculationThrottle = Duration(milliseconds: 500);
  static const int minSamplesRequired = 50; // Minimum samples for validation (5 seconds at 10Hz)
}

/// Electrode validation state enumeration
enum ElectrodeValidationState {
  initializing,
  collectingData,
  validating,
  valid,
  invalid,
  insufficientData,
  connectionLost,
}

/// Extension for electrode validation state display
extension ElectrodeValidationStateExtension on ElectrodeValidationState {
  /// Get localized display text for validation state
  String get displayText {
    switch (this) {
      case ElectrodeValidationState.initializing:
        return 'Инициализация проверки электродов...';
      case ElectrodeValidationState.collectingData:
        return 'Сбор данных для проверки...';
      case ElectrodeValidationState.validating:
        return 'Проверка качества соединения...';
      case ElectrodeValidationState.valid:
        return 'Электроды подключены корректно';
      case ElectrodeValidationState.invalid:
        return 'Проблемы с контактом электродов.\nУбедитесь, что между кожей и электродами нет волос.\nЕсли проблема продолжается, попробуйте аккуратно поправить один из электродов\nлибо же смочить контакты водой.';
      case ElectrodeValidationState.insufficientData:
        return 'Недостаточно данных для проверки. Убедитесь, что устройство подключено.';
      case ElectrodeValidationState.connectionLost:
        return 'Потеряно соединение с устройством. Проверьте подключение.';
    }
  }

  /// Check if the state allows proceeding to next screen
  bool get canProceed {
    return this == ElectrodeValidationState.valid;
  }

  /// Check if the state indicates an error condition
  bool get isError {
    return this == ElectrodeValidationState.invalid ||
           this == ElectrodeValidationState.connectionLost;
  }

  /// Check if the state indicates loading/processing
  bool get isLoading {
    return this == ElectrodeValidationState.initializing ||
           this == ElectrodeValidationState.collectingData ||
           this == ElectrodeValidationState.validating;
  }
}

/// Result of electrode validation analysis
class ValidationResult {
  final bool isRangeValid;
  final bool isVarianceValid;
  final double currentVariance;
  final int sampleCount;
  final double minValue;
  final double maxValue;
  final ElectrodeValidationState state;
  final DateTime timestamp;

  const ValidationResult({
    required this.isRangeValid,
    required this.isVarianceValid,
    required this.currentVariance,
    required this.sampleCount,
    required this.minValue,
    required this.maxValue,
    required this.state,
    required this.timestamp,
  });

  /// Check if validation passed (both range and variance valid)
  bool get isValid => isRangeValid && isVarianceValid;

  /// Factory constructor for insufficient data
  factory ValidationResult.insufficientData() {
    return ValidationResult(
      isRangeValid: false,
      isVarianceValid: false,
      currentVariance: 0.0,
      sampleCount: 0,
      minValue: 0.0,
      maxValue: 0.0,
      state: ElectrodeValidationState.insufficientData,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for connection lost
  factory ValidationResult.connectionLost() {
    return ValidationResult(
      isRangeValid: false,
      isVarianceValid: false,
      currentVariance: 0.0,
      sampleCount: 0,
      minValue: 0.0,
      maxValue: 0.0,
      state: ElectrodeValidationState.connectionLost,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ValidationResult(state: $state, valid: $isValid, samples: $sampleCount, variance: ${currentVariance.toStringAsFixed(2)}, range: [$minValue, $maxValue])';
  }

  /// Copy with new values
  ValidationResult copyWith({
    bool? isRangeValid,
    bool? isVarianceValid,
    double? currentVariance,
    int? sampleCount,
    double? minValue,
    double? maxValue,
    ElectrodeValidationState? state,
    DateTime? timestamp,
  }) {
    return ValidationResult(
      isRangeValid: isRangeValid ?? this.isRangeValid,
      isVarianceValid: isVarianceValid ?? this.isVarianceValid,
      currentVariance: currentVariance ?? this.currentVariance,
      sampleCount: sampleCount ?? this.sampleCount,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      state: state ?? this.state,
      timestamp: timestamp ?? this.timestamp,
    );
  }
} 