import 'dart:convert';
import 'dart:async';
import 'dart:collection';

/// JSON-based EEG sample for new data format with brainwave bands and ratios
class EEGJsonSample {
  final int eegValue;
  final DateTime absoluteTimestamp;
  final int delta;
  final int theta;
  final int alpha;
  final int beta;
  final int gamma;
  final double btr;    // beta / theta (0 if theta is 0)
  final double atr;    // alpha / theta (0 if theta is 0)
  final double pope;   // beta / (theta + alpha) (0 if theta is 0 and alpha is 0)
  final double gtr;    // gamma / theta (0 if theta is 0)
  final double rab;    // alpha / beta (0 if beta is 0)

  const EEGJsonSample({
    required this.eegValue,
    required this.absoluteTimestamp,
    required this.delta,
    required this.theta,
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.btr,
    required this.atr,
    required this.pope,
    required this.gtr,
    required this.rab,
  });

  /// Create from JSON string with time delta processing
  factory EEGJsonSample.fromJson(String jsonString, TimeDeltaProcessor processor) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return EEGJsonSample.fromMap(json, processor);
    } catch (e) {
      throw EEGJsonParseException('Invalid JSON format: $e');
    }
  }

  /// Create from JSON map with validation and brainwave band calculations
  factory EEGJsonSample.fromMap(Map<String, dynamic> json, TimeDeltaProcessor processor) {
    // Validate mandatory fields
    if (!json.containsKey('E')) {
      throw EEGJsonParseException('Missing mandatory field: E (EEG value) is required');
    }

    // Extract EEG value
    int eegValue = double.parse(json['E']).toInt();

    // Extract brainwave band components and calculate brainwave band values
    int delta = json['d1'];
    int theta = json['t1'] + json['t2'];
    int alpha = json['a1'] + json['a2'];
    int beta = json['b1'] + json['b2'] + json['b3'];
    int gamma = json['g1'];

    // Calculate brainwave ratios with division by zero protection
    double btr = theta == 0 ? 0.0 : beta.toDouble() / theta.toDouble();
    double atr = theta == 0 ? 0.0 : alpha.toDouble() / theta.toDouble();
    double pope = (theta == 0 && alpha == 0) ? 0.0 : beta.toDouble() / (theta.toDouble() + alpha.toDouble());
    double gtr = theta == 0 ? 0.0 : gamma.toDouble() / theta.toDouble();
    double rab = beta == 0 ? 0.0 : alpha.toDouble() / beta.toDouble();

    // Process time delta to absolute timestamp
    final absoluteTimestamp = processor.processDelta();

    return EEGJsonSample(
      eegValue: eegValue,
      absoluteTimestamp: absoluteTimestamp,
      delta: delta,
      theta: theta,
      alpha: alpha,
      beta: beta,
      gamma: gamma,
      btr: btr,
      atr: atr,
      pope: pope,
      gtr: gtr,
      rab: rab,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'E': eegValue,
      'delta': delta,
      'theta': theta,
      'alpha': alpha,
      'beta': beta,
      'gamma': gamma,
      'btr': btr,
      'atr': atr,
      'pope': pope,
      'gtr': gtr,
      'rab': rab,
      'absoluteTimestamp': absoluteTimestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'EEGJsonSample(eegValue: $eegValue, delta: $delta, theta: $theta, alpha: $alpha, beta: $beta, gamma: $gamma, btr: $btr, atr: $atr, pope: $pope, gtr: $gtr, rab: $rab)';
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
  DateTime processDelta() {    
    // Add to accumulated time
    _accumulatedTime += 10.0;
    
    // Store in history for drift correction
    _deltaHistory.addLast(10.0);
    
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
    return processDelta(); // Default to 10ms
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
  final String deviceAddress;
  final int devicePort;
  final int bufferSize;

  const EEGConfig({
    required this.deviceAddress,
    required this.devicePort,
    this.bufferSize = 13000, // Default to 130 seconds at 100Hz (130 * 100 = 13,000 samples)
  });

  factory EEGConfig.defaultConfig() {
    return const EEGConfig(
      deviceAddress: '0.0.0.0',
      devicePort: 2000,
      bufferSize: 13000, // 130 seconds * 100 samples/second = 13,000 samples
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
      eegValue: 0, 
      absoluteTimestamp: DateTime.now(), 
      delta: 0,
      theta: 0,
      alpha: 0,
      beta: 0,
      gamma: 0,
      btr: 0.0,
      atr: 0.0,
      pope: 0.0,
      gtr: 0.0,
      rab: 0.0,
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