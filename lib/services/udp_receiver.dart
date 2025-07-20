import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/eeg_data.dart';
import '../models/connection_state.dart';

/// UDP receiver service for EEG data with JSON support
class UDPReceiver {
  RawDatagramSocket? _socket;
  late StreamController<EEGJsonSample> _jsonDataController;
  late StreamController<ConnectionState> _connectionController;
  late TimeDeltaProcessor _timeDeltaProcessor;
  
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  // Configuration
  String? _address;
  int? _port;
  bool _isRunning = false;
  
  // Statistics
  int _sequenceNumber = 0;
  int _packetsReceived = 0;
  int _packetsLost = 0;
  int _jsonPacketsReceived = 0;
  int _jsonParseErrors = 0;
  DateTime? _lastDataReceived;
  DateTime? _connectionStartTime;
  
  // Rate calculation
  final List<DateTime> _packetTimes = [];
  static const int _rateCalculationWindow = 50; // packets
  
  ConnectionState _currentState = ConnectionState.disconnected();

  UDPReceiver() {
    _jsonDataController = StreamController<EEGJsonSample>.broadcast();
    _connectionController = StreamController<ConnectionState>.broadcast();
    _timeDeltaProcessor = TimeDeltaProcessor();
  }
  
  /// Stream of EEG JSON data samples (new format)
  Stream<EEGJsonSample> get jsonDataStream => _jsonDataController.stream;
  
  /// Stream of connection state changes
  Stream<ConnectionState> get connectionStream => _connectionController.stream;
  
  /// Current connection state
  ConnectionState get currentState => _currentState;
  
  /// Whether the receiver is currently running
  bool get isRunning => _isRunning;
  
  /// Time delta processor for JSON format
  TimeDeltaProcessor get timeDeltaProcessor => _timeDeltaProcessor;

  /// Start receiving UDP data
  Future<void> start(String address, int port) async {
    if (_isRunning) {
      throw StateError('UDP receiver is already running');
    }

    _address = address;
    _port = port;
    
    // Reset time delta processor when starting
    _timeDeltaProcessor.reset();
    
    await _connect();
  }

  /// Stop receiving UDP data
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    
    // Cancel timers
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    // Close socket
    _socket?.close();
    _socket = null;
    
    // Update state
    _updateConnectionState(ConnectionState.disconnected());
    
    // Clear statistics
    _resetStatistics();
  }

  /// Force reconnection
  Future<void> reconnect() async {
    if (_address == null || _port == null) return;
    
    await stop();
    await _connect();
  }

  Future<void> _connect() async {
    try {
      _updateConnectionState(ConnectionState.connecting());
      
      // Bind to any address to receive UDP packets
      // Note: For receiving, we typically bind to INADDR_ANY
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port!);
      
      _socket!.listen(
        _handleSocketEvent,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
      );
      
      _isRunning = true;
      _connectionStartTime = DateTime.now();
      _updateConnectionState(ConnectionState.connected());
      
      // Start heartbeat monitoring
      _startHeartbeat();
      
    } catch (error) {
      _updateConnectionState(ConnectionState.error(error.toString()));
      _scheduleReconnect();
    }
  }

  void _handleSocketEvent(RawSocketEvent event) {
    try {
      if (event == RawSocketEvent.read) {
        final packet = _socket?.receive();
        if (packet != null) {
          _processPacket(packet.data);
        }
      }
    } catch (error) {
      _updateConnectionState(ConnectionState.error('Failed to process packet: $error'));
    }
  }

  void _handleSocketError(error) {
    _updateConnectionState(ConnectionState.error('Socket error: $error'));
    _scheduleReconnect();
  }

  void _handleSocketDone() {
    if (_isRunning) {
      _updateConnectionState(ConnectionState.error('Connection closed unexpectedly'));
      _scheduleReconnect();
    }
  }

  void _processPacket(Uint8List data) {
    try {
      // Update statistics
      _packetsReceived++;
      _lastDataReceived = DateTime.now();
      
      // Track packet rate
      _packetTimes.add(_lastDataReceived!);
      if (_packetTimes.length > _rateCalculationWindow) {
        _packetTimes.removeAt(0);
      }
      
      _processJsonPacket(data);
      
      // Update connection state with new statistics
      _updateConnectionState(_currentState.copyWith(
        lastDataReceived: _lastDataReceived,
        packetsReceived: _packetsReceived,
        packetsLost: _packetsLost,
        dataRate: _calculateDataRate(),
      ));
      
    } catch (error) {
      debugPrint('Error processing packet: $error');
      // Don't emit error for individual packet processing failures
    }
  }

  void _processJsonPacket(Uint8List data) {
    try {
      // Convert UDP data to string
      final jsonString = utf8.decode(data);
      
      // Parse JSON sample
      final jsonSample = EEGJsonSample.fromJson(
        jsonString, 
        _timeDeltaProcessor, 
        _sequenceNumber++
      );
      
      _jsonPacketsReceived++;
      
      // Emit JSON sample
      _jsonDataController.add(jsonSample);
      
    } catch (e) {
      _jsonParseErrors++;
      debugPrint('JSON parsing error: $e');
      
      // Try to handle as missing/malformed data
      if (e is EEGJsonParseException) {
        _handleMalformedJsonData(e);
      }
    }
  }

  void _handleMalformedJsonData(EEGJsonParseException error) {
    // Create a sample with predicted timestamp for continuity
    try {
      final predictedTimestamp = _timeDeltaProcessor.handleMissingDelta();
      
      final fallbackSample = EEGJsonSample(
        timeDelta: 100.0, // Default 100ms
        eegValue: 0.0, // Neutral value
        absoluteTimestamp: predictedTimestamp,
        sequenceNumber: _sequenceNumber++,
      );
      
      _jsonDataController.add(fallbackSample);
      
    } catch (e) {
      debugPrint('Failed to create fallback sample: $e');
    }
  }

  double _calculateDataRate() {
    if (_packetTimes.length < 2) return 0.0;
    
    final now = DateTime.now();
    final oldest = _packetTimes.first;
    final duration = now.difference(oldest);
    
    if (duration.inMilliseconds == 0) return 0.0;
    
    return _packetTimes.length / (duration.inMilliseconds / 1000.0);
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectionHealth();
    });
  }

  void _checkConnectionHealth() {
    if (_lastDataReceived == null) return;
    
    final timeSinceLastData = DateTime.now().difference(_lastDataReceived!);
    
    // If no data received for 10 seconds, consider connection unhealthy
    if (timeSinceLastData.inSeconds > 10) {
      _updateConnectionState(ConnectionState.error('No data received for ${timeSinceLastData.inSeconds} seconds'));
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) return;
    
    _updateConnectionState(ConnectionState.reconnecting());
    
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_address != null && _port != null) {
        _connect();
      }
    });
  }

  void _updateConnectionState(ConnectionState newState) {
    _currentState = newState;
    _connectionController.add(newState);
  }

  void _resetStatistics() {
    _sequenceNumber = 0;
    _packetsReceived = 0;
    _packetsLost = 0;
    _jsonPacketsReceived = 0;
    _jsonParseErrors = 0;
    _lastDataReceived = null;
    _connectionStartTime = null;
    _packetTimes.clear();
  }

  /// Get current network statistics
  NetworkStats get networkStats {
    return NetworkStats(
      totalPacketsReceived: _packetsReceived,
      totalPacketsLost: _packetsLost,
      averageDataRate: _calculateDataRate(),
      currentDataRate: _calculateDataRate(),
      startTime: _connectionStartTime ?? DateTime.now(),
      connectionDuration: _connectionStartTime != null 
        ? DateTime.now().difference(_connectionStartTime!)
        : Duration.zero,
    );
  }

  /// Get JSON-specific statistics
  Map<String, dynamic> get jsonStats {
    return {
      'jsonPacketsReceived': _jsonPacketsReceived,
      'jsonParseErrors': _jsonParseErrors,
      'parseSuccessRate': _jsonPacketsReceived > 0 
        ? (_jsonPacketsReceived / (_jsonPacketsReceived + _jsonParseErrors)) * 100
        : 0.0,
      'timeDeltaProcessorStats': _timeDeltaProcessor.getStats(),
    };
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _timeDeltaProcessor.dispose();
    await stop();
    await _jsonDataController.close();
    await _connectionController.close();
  }
} 