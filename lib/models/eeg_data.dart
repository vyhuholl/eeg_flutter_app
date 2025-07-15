import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:collection';

/// EEG data models for handling electroencephalography data
class EEGSample {
  final DateTime timestamp;
  final List<double> channels;
  final int sampleRate;
  final int sequenceNumber;

  const EEGSample({
    required this.timestamp,
    required this.channels,
    required this.sampleRate,
    required this.sequenceNumber,
  });

  factory EEGSample.fromBytes(List<int> bytes, int sequenceNumber) {
    // Parse UDP packet bytes into EEG sample
    // This is a simplified parser - adjust based on actual EEG device protocol
    final channelCount = bytes.length ~/ 4; // Assuming 4 bytes per channel (float32)
    final channels = <double>[];
    
    for (int i = 0; i < channelCount; i++) {
      final index = i * 4;
      if (index + 3 < bytes.length) {
        // Convert 4 bytes to float32 (little-endian)
        final value = _bytesToFloat32(bytes.sublist(index, index + 4));
        channels.add(value);
      }
    }

    return EEGSample(
      timestamp: DateTime.now(),
      channels: channels,
      sampleRate: 250, // Default sample rate, should be configurable
      sequenceNumber: sequenceNumber,
    );
  }

  static double _bytesToFloat32(List<int> bytes) {
    // Convert 4 bytes to float32 (little-endian)
    // This is a simplified conversion - may need adjustment based on device
    final buffer = ByteData.sublistView(Uint8List.fromList(bytes));
    return buffer.getFloat32(0, Endian.little);
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'channels': channels,
      'sampleRate': sampleRate,
      'sequenceNumber': sequenceNumber,
    };
  }

  @override
  String toString() {
    return 'EEGSample(timestamp: $timestamp, channels: ${channels.length}, seq: $sequenceNumber)';
  }
}

/// JSON-based EEG sample for new data format
class EEGJsonSample {
  final double timeDelta;
  final double eegValue;
  final Map<int, double>? powerSpectrum;
  final DateTime absoluteTimestamp;
  final int sequenceNumber;

  const EEGJsonSample({
    required this.timeDelta,
    required this.eegValue,
    this.powerSpectrum,
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

    // Parse optional power spectrum data (1-49 Hz)
    Map<int, double>? powerSpectrum;
    final spectrumData = <int, double>{};
    
    for (int freq = 1; freq <= 49; freq++) {
      final key = '${freq}Hz';  // Changed from freq.toString() to '${freq}Hz'
      if (json.containsKey(key)) {
        double power = _parseDouble(json[key]);
        if (power >= 0 && power <= 100) {
          spectrumData[freq] = power;
        }
      }
    }

    if (spectrumData.isNotEmpty) {
      powerSpectrum = spectrumData;
    }

    // Process time delta to absolute timestamp
    final absoluteTimestamp = processor.processDelta(timeDelta);

    return EEGJsonSample(
      timeDelta: timeDelta,
      eegValue: eegValue,
      powerSpectrum: powerSpectrum,
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

  /// Check if spectrum data is available
  bool get hasSpectrumData => powerSpectrum != null && powerSpectrum!.isNotEmpty;

  /// Get power spectrum data as PowerSpectrumData
  PowerSpectrumData? get spectrumData {
    if (!hasSpectrumData) return null;
    return PowerSpectrumData(powerSpectrum!);
  }

  /// Convert to legacy EEGSample format for backward compatibility
  EEGSample toLegacyEEGSample() {
    return EEGSample(
      timestamp: absoluteTimestamp,
      channels: [eegValue], // Single channel for EEG value
      sampleRate: 250, // Default sample rate
      sequenceNumber: sequenceNumber,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'd': timeDelta,
      'E': eegValue,
      'absoluteTimestamp': absoluteTimestamp.millisecondsSinceEpoch,
      'sequenceNumber': sequenceNumber,
    };

    // Add power spectrum data if available
    if (hasSpectrumData) {
      for (final entry in powerSpectrum!.entries) {
        json[entry.key.toString()] = entry.value;
      }
    }

    return json;
  }

  @override
  String toString() {
    return 'EEGJsonSample(timeDelta: ${timeDelta}ms, eegValue: $eegValue, spectrum: ${hasSpectrumData ? '${powerSpectrum!.length} frequencies' : 'none'}, seq: $sequenceNumber)';
  }
}

/// Power spectrum data for frequency analysis
class PowerSpectrumData {
  final Map<int, double> _frequencies;

  PowerSpectrumData(this._frequencies);

  /// Get power at specific frequency
  double? getPowerAt(int frequency) {
    return _frequencies[frequency];
  }

  /// Get all frequencies with power data
  List<int> get frequencies => _frequencies.keys.toList()..sort();

  /// Get all power values in frequency order
  List<double> get powers => frequencies.map((f) => _frequencies[f]!).toList();

  /// Get frequency range
  int get minFrequency => frequencies.isEmpty ? 0 : frequencies.first;
  int get maxFrequency => frequencies.isEmpty ? 0 : frequencies.last;

  /// Get frequency count
  int get frequencyCount => _frequencies.length;

  /// Get power by frequency bands
  Map<FrequencyBand, double> get powerByBands {
    final result = <FrequencyBand, double>{};
    
    for (final band in FrequencyBand.values) {
      double totalPower = 0;
      int count = 0;
      
      for (final freq in frequencies) {
        if (freq >= band.minFreq && freq <= band.maxFreq) {
          totalPower += _frequencies[freq]!;
          count++;
        }
      }
      
      result[band] = count > 0 ? totalPower / count : 0;
    }
    
    return result;
  }

  /// Get peak frequency (frequency with highest power)
  int? get peakFrequency {
    if (_frequencies.isEmpty) return null;
    
    double maxPower = 0;
    int? peakFreq;
    
    for (final entry in _frequencies.entries) {
      if (entry.value > maxPower) {
        maxPower = entry.value;
        peakFreq = entry.key;
      }
    }
    
    return peakFreq;
  }

  /// Get total power across all frequencies
  double get totalPower => _frequencies.values.fold(0.0, (sum, power) => sum + power);

  @override
  String toString() {
    return 'PowerSpectrumData(frequencies: ${frequencies.join(', ')}, peak: ${peakFrequency}Hz)';
  }
}

/// EEG frequency bands for clinical interpretation
enum FrequencyBand {
  delta(1, 4, 'Delta', 'Deep sleep, meditation'),
  theta(4, 8, 'Theta', 'Light sleep, creativity'),
  alpha(8, 13, 'Alpha', 'Relaxed awareness'),
  beta(13, 30, 'Beta', 'Active thinking'),
  gamma(30, 49, 'Gamma', 'High-level cognitive processing');

  const FrequencyBand(this.minFreq, this.maxFreq, this.name, this.description);

  final int minFreq;
  final int maxFreq;
  final String name;
  final String description;
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
  final int channelCount;
  final List<String> channelNames;
  final String deviceAddress;
  final int devicePort;
  final int bufferSize;

  const EEGConfig({
    required this.sampleRate,
    required this.channelCount,
    required this.channelNames,
    required this.deviceAddress,
    required this.devicePort,
    this.bufferSize = 1000,
  });

  factory EEGConfig.defaultConfig() {
    return const EEGConfig(
      sampleRate: 250,
      channelCount: 8,
      channelNames: ['CH1', 'CH2', 'CH3', 'CH4', 'CH5', 'CH6', 'CH7', 'CH8'],
      deviceAddress: '0.0.0.0',
      devicePort: 2000,
    );
  }
}

/// Circular buffer for efficient EEG data storage
class EEGBuffer {
  final List<EEGSample> _buffer;
  final int _maxSize;
  int _currentIndex = 0;
  int _count = 0;

  EEGBuffer(this._maxSize) : _buffer = List.filled(_maxSize, 
    EEGSample(timestamp: DateTime.now(), channels: [], sampleRate: 0, sequenceNumber: 0));

  void add(EEGSample sample) {
    _buffer[_currentIndex] = sample;
    _currentIndex = (_currentIndex + 1) % _maxSize;
    if (_count < _maxSize) _count++;
  }

  List<EEGSample> getLatest(int count) {
    if (_count == 0) return [];
    
    final result = <EEGSample>[];
    final actualCount = count > _count ? _count : count;
    
    for (int i = 0; i < actualCount; i++) {
      final index = (_currentIndex - actualCount + i + _maxSize) % _maxSize;
      result.add(_buffer[index]);
    }
    
    return result;
  }

  List<EEGSample> getAll() {
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

  /// Get samples with spectrum data
  List<EEGJsonSample> getSpectrumSamples([int count = 100]) {
    return getLatest(count).where((sample) => sample.hasSpectrumData).toList();
  }

  /// Get latest spectrum data
  PowerSpectrumData? getLatestSpectrumData() {
    final spectrumSamples = getSpectrumSamples(10);
    return spectrumSamples.isNotEmpty ? spectrumSamples.last.spectrumData : null;
  }

  int get length => _count;
  bool get isEmpty => _count == 0;
  bool get isFull => _count == _maxSize;
  
  void clear() {
    _count = 0;
    _currentIndex = 0;
  }
} 