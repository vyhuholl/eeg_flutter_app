import 'dart:convert';
import 'dart:async';
import 'dart:collection';

/// JSON-based EEG sample for new data format
class EEGJsonSample {
  final double timeDelta;
  final double eegValue;
  final DateTime absoluteTimestamp;
  final int sequenceNumber;

  const EEGJsonSample({
    required this.timeDelta,
    required this.eegValue,
    required this.absoluteTimestamp,
    required this.sequenceNumber,
  });

  /// Create from JSON string with time delta processing
  factory EEGJsonSample.fromJson(String jsonString, TimeDeltaProcessor processor, int sequenceNumber) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return EEGJsonSample.fromMap(json, processor, sequenceNumber);
    } catch (e) {
      throw EEGJsonParseException('Invalid JSON format: $e');
    }
  }

  /// Create from JSON map with validation
  factory EEGJsonSample.fromMap(Map<String, dynamic> json, TimeDeltaProcessor processor, int sequenceNumber) {
    // Validate mandatory fields
    if (!json.containsKey('d') || !json.containsKey('E')) {
      throw EEGJsonParseException('Missing mandatory fields: d (time delta) and E (EEG value) are required');
    }

    double timeDelta = _parseDouble(json['d']);
    double eegValue = _parseDouble(json['E']);

    // Validate time delta range
    if (timeDelta <= 0 || timeDelta > 5000) {
      throw EEGJsonParseException('Invalid time delta: $timeDelta ms (must be > 0 and <= 5000)');
    }

    // Process time delta to absolute timestamp
    final absoluteTimestamp = processor.processDelta(timeDelta);

    return EEGJsonSample(
      timeDelta: timeDelta,
      eegValue: eegValue,
      absoluteTimestamp: absoluteTimestamp,
      sequenceNumber: sequenceNumber,
    );
  }

  /// Helper method to parse double from dynamic value
  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.parse(value);
    } else {
      throw EEGJsonParseException('Invalid numeric value: $value (type: ${value.runtimeType})');
    }
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'd': timeDelta,
      'E': eegValue,
      'absoluteTimestamp': absoluteTimestamp.millisecondsSinceEpoch,
      'sequenceNumber': sequenceNumber,
    };
  }

  @override
  String toString() {
    return 'EEGJsonSample(timeDelta: ${timeDelta}ms, eegValue: $eegValue, seq: $sequenceNumber)';
  }
}



/// Time delta processor with weighted moving average drift correction
class TimeDeltaProcessor {
  late DateTime _baseTimestamp;
  late double _accumulatedTime;
  late Queue<double> _deltaHistory;
  late double _driftCorrection;
  Timer? _correctionTimer;

  // Configuration parameters
  static const int _historySize = 100;
  static const double _correctionWeight = 0.1;
  static const Duration _correctionInterval = Duration(seconds: 10);

  TimeDeltaProcessor() {
    _initialize();
  }

  void _initialize() {
    _baseTimestamp = DateTime.now();
    _accumulatedTime = 0.0;
    _deltaHistory = Queue<double>();
    _driftCorrection = 0.0;
    _startPeriodicCorrection();
  }

  /// Process time delta and return absolute timestamp
  DateTime processDelta(double deltaMs) {
    // Validate delta range
    final clampedDelta = deltaMs.clamp(1.0, 5000.0);
    
    // Add to accumulated time
    _accumulatedTime += clampedDelta;
    
    // Store in history for drift correction
    _deltaHistory.addLast(clampedDelta);
    
    // Maintain history size
    if (_deltaHistory.length > _historySize) {
      _deltaHistory.removeFirst();
    }
    
    // Apply drift correction if history is sufficient
    if (_deltaHistory.length >= 10) {
      _applyDriftCorrection();
    }
    
    // Calculate absolute timestamp
    final absoluteTime = _baseTimestamp.add(
      Duration(milliseconds: (_accumulatedTime + _driftCorrection).round())
    );
    
    return absoluteTime;
  }

  void _applyDriftCorrection() {
    if (_deltaHistory.isEmpty) return;
    
    // Calculate expected delta (weighted moving average)
    final expectedDelta = _calculateExpectedDelta();
    final actualDelta = _deltaHistory.last;
    
    // Calculate correction factor
    final driftError = expectedDelta - actualDelta;
    _driftCorrection += driftError * _correctionWeight;
    
    // Clamp correction to prevent excessive drift
    _driftCorrection = _driftCorrection.clamp(-1000.0, 1000.0);
  }

  double _calculateExpectedDelta() {
    if (_deltaHistory.isEmpty) return 0.0;
    
    // Weighted moving average with more weight on recent values
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    final history = _deltaHistory.toList();
    for (int i = 0; i < history.length; i++) {
      final weight = (i + 1.0) / history.length; // Linear weight increase
      weightedSum += history[i] * weight;
      totalWeight += weight;
    }
    
    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  void _startPeriodicCorrection() {
    _correctionTimer?.cancel();
    _correctionTimer = Timer.periodic(_correctionInterval, (timer) {
      _performPeriodicCorrection();
    });
  }

  void _performPeriodicCorrection() {
    // Synchronize with system time periodically
    final now = DateTime.now();
    final expectedTime = _baseTimestamp.add(
      Duration(milliseconds: (_accumulatedTime + _driftCorrection).round())
    );
    
    final timeDiff = now.difference(expectedTime).inMilliseconds;
    
    // Apply gradual correction if drift is significant
    if (timeDiff.abs() > 1000) {
      _driftCorrection += timeDiff * 0.01; // Gradual correction
    }
  }

  /// Handle missing delta by using predicted value
  DateTime handleMissingDelta() {
    final predictedDelta = _calculateExpectedDelta();
    return processDelta(predictedDelta > 0 ? predictedDelta : 100.0); // Default to 100ms
  }

  /// Reset processor with new base timestamp
  void reset() {
    _correctionTimer?.cancel();
    _initialize();
  }

  /// Get current statistics
  Map<String, dynamic> getStats() {
    return {
      'baseTimestamp': _baseTimestamp.millisecondsSinceEpoch,
      'accumulatedTime': _accumulatedTime,
      'driftCorrection': _driftCorrection,
      'historySize': _deltaHistory.length,
      'averageDelta': _deltaHistory.isEmpty ? 0.0 : _deltaHistory.reduce((a, b) => a + b) / _deltaHistory.length,
    };
  }

  /// Dispose resources
  void dispose() {
    _correctionTimer?.cancel();
    _correctionTimer = null;
  }
}

/// Exception for JSON parsing errors
class EEGJsonParseException implements Exception {
  final String message;
  EEGJsonParseException(this.message);
  
  @override
  String toString() => 'EEGJsonParseException: $message';
}

/// Configuration for EEG data collection
class EEGConfig {
  final int sampleRate;
  final String deviceAddress;
  final int devicePort;
  final int bufferSize;

  const EEGConfig({
    required this.sampleRate,
    required this.deviceAddress,
    required this.devicePort,
    this.bufferSize = 1000,
  });

  factory EEGConfig.defaultConfig() {
    return const EEGConfig(
      sampleRate: 250,
      deviceAddress: '0.0.0.0',
      devicePort: 2000,
    );
  }
}

/// Circular buffer for JSON EEG samples
class EEGJsonBuffer {
  final List<EEGJsonSample> _buffer;
  final int _maxSize;
  int _currentIndex = 0;
  int _count = 0;

  EEGJsonBuffer(this._maxSize) : _buffer = List.filled(_maxSize, 
    EEGJsonSample(
      timeDelta: 0, 
      eegValue: 0, 
      absoluteTimestamp: DateTime.now(), 
      sequenceNumber: 0
    ));

  void add(EEGJsonSample sample) {
    _buffer[_currentIndex] = sample;
    _currentIndex = (_currentIndex + 1) % _maxSize;
    if (_count < _maxSize) _count++;
  }

  List<EEGJsonSample> getLatest(int count) {
    if (_count == 0) return [];
    
    final result = <EEGJsonSample>[];
    final actualCount = count > _count ? _count : count;
    
    for (int i = 0; i < actualCount; i++) {
      final index = (_currentIndex - actualCount + i + _maxSize) % _maxSize;
      result.add(_buffer[index]);
    }
    
    return result;
  }

  List<EEGJsonSample> getAll() {
    return getLatest(_count);
  }



  int get length => _count;
  bool get isEmpty => _count == 0;
  bool get isFull => _count == _maxSize;
  
  void clear() {
    _count = 0;
    _currentIndex = 0;
  }
} 