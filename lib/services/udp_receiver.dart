import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/eeg_data.dart';
import '../models/connection_state.dart';

/// UDP receiver service for EEG data
class UDPReceiver {
  RawDatagramSocket? _socket;
  late StreamController<EEGSample> _dataController;
  late StreamController<ConnectionState> _connectionController;
  
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
  DateTime? _lastDataReceived;
  DateTime? _connectionStartTime;
  
  // Rate calculation
  final List<DateTime> _packetTimes = [];
  static const int _rateCalculationWindow = 50; // packets
  
  ConnectionState _currentState = ConnectionState.disconnected();

  UDPReceiver() {
    _dataController = StreamController<EEGSample>.broadcast();
    _connectionController = StreamController<ConnectionState>.broadcast();
  }

  /// Stream of EEG data samples
  Stream<EEGSample> get dataStream => _dataController.stream;
  
  /// Stream of connection state changes
  Stream<ConnectionState> get connectionStream => _connectionController.stream;
  
  /// Current connection state
  ConnectionState get currentState => _currentState;
  
  /// Whether the receiver is currently running
  bool get isRunning => _isRunning;

  /// Start receiving UDP data
  Future<void> start(String address, int port) async {
    if (_isRunning) {
      throw StateError('UDP receiver is already running');
    }

    _address = address;
    _port = port;
    
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
      
      // Create EEG sample from packet data
      final sample = EEGSample.fromBytes(data, _sequenceNumber++);
      
      // Emit the sample
      _dataController.add(sample);
      
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

  /// Dispose of resources
  Future<void> dispose() async {
    await stop();
    await _dataController.close();
    await _connectionController.close();
  }
} 