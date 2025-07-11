import 'dart:typed_data';

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
      deviceAddress: '192.168.1.100',
      devicePort: 12345,
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