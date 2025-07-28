import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/eeg_chart.dart';
import '../widgets/electrode_status_widget.dart';
import '../providers/eeg_data_provider.dart';
import '../models/eeg_data.dart';
import 'meditation_selection_screen.dart';

/// Meditation screen with timer and visual elements
class MeditationScreen extends StatefulWidget {
  final MeditationType meditationType;
  
  const MeditationScreen({
    super.key,
    this.meditationType = MeditationType.concentration,
  });

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  late Timer _timer;
  late Timer _animationTimer;
  int _seconds = 0;
  
  // Value tracking for circle animation (Pope for concentration, RAB for relaxation)
  double? _baselineValue;
  double _currentCircleSize = 250.0;
  bool _isBaselineRecorded = false;
  
  // Sliding window state for O(n) value calculation
  final List<EEGJsonSample> _valueWindow = [];
  double _valueRunningSum = 0.0;
  int _validValueCount = 0;
  static const int _valueWindowDurationMs = 10 * 1000; // 10 seconds

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startAnimationTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationTimer.cancel();
    
    // Clean up sliding window state
    _valueWindow.clear();
    _valueRunningSum = 0.0;
    _validValueCount = 0;
    
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        // Stop timer after 5 minutes (300 seconds)
        if (_seconds >= 300) {
          _timer.cancel();
        }
      });
    });
  }

  String _formatTime() {
    final minutes = _seconds ~/ 60;
    final remainingSeconds = _seconds % 60;
    // No leading zero for minutes as requested
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _endMeditation() {
    // Navigate back to start screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _startAnimationTimer() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _updateCircleAnimation();
    });
  }

  void _updateCircleAnimation() {
    final eegProvider = Provider.of<EEGDataProvider>(context, listen: false);
    final currentValue = _calculateCurrentValue(eegProvider);
    
    // Record baseline value on first calculation
    if (!_isBaselineRecorded && currentValue > 0.0) {
      _baselineValue = currentValue;
      _isBaselineRecorded = true;
    }
    
    // Update circle size if we have a baseline
    if (_isBaselineRecorded && _baselineValue != null) {
      final newSize = _calculateCircleSize(currentValue, _baselineValue!);
      if ((newSize - _currentCircleSize).abs() > 1.0) {
        setState(() {
          _currentCircleSize = newSize;
        });
      }
    }
  }

  double _calculateCurrentValue(EEGDataProvider eegProvider) {
    final jsonSamples = eegProvider.dataProcessor.getLatestJsonSamples();
    
    if (jsonSamples.isEmpty) return 0.0;
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final windowStartTime = currentTime - _valueWindowDurationMs;
    
    // Add new samples to sliding window
    for (final sample in jsonSamples) {
      final sampleTime = sample.absoluteTimestamp.millisecondsSinceEpoch;
      
      // Only process samples that are within our time window and not already in window
      if (sampleTime >= windowStartTime && 
          (_valueWindow.isEmpty || sampleTime > _valueWindow.last.absoluteTimestamp.millisecondsSinceEpoch)) {
        _valueWindow.add(sample);
        
        // Add to running sum based on meditation type
        final value = widget.meditationType == MeditationType.concentration ? sample.pope : sample.rab;
        if (value != 0.0) {
          _valueRunningSum += value;
          _validValueCount++;
        }
      }
    }
    
    // Remove samples that fall outside the 10-second window
    while (_valueWindow.isNotEmpty && 
           _valueWindow.first.absoluteTimestamp.millisecondsSinceEpoch < windowStartTime) {
      final removedSample = _valueWindow.removeAt(0);
      
      // Remove from running sum based on meditation type
      final value = widget.meditationType == MeditationType.concentration ? removedSample.pope : removedSample.rab;
      if (value != 0.0) {
        _valueRunningSum -= value;
        _validValueCount--;
      }
    }
    
    // Calculate moving average
    return _validValueCount > 0 ? _valueRunningSum / _validValueCount : 0.0;
  }

  double _calculateCircleSize(double currentValue, double baselineValue) {
    const double baseSize = 250.0;
    const double maxSize = 500.0;
    const double minSize = 50.0;
    
    // Calculate proportional change
    final valueRatio = baselineValue != 0.0 ? currentValue / baselineValue : 1.0;
    final newSize = baseSize * valueRatio;
    
    // Apply constraints
    return newSize.clamp(minSize, maxSize);
  }

  Widget _buildLegend() {
    return Column(
      children: [
        // First row: Pope and BTR
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pope indicator (violet)
            Row(
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: const Color(0xFFBF5AF2), // Violet
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pope',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 24),
            
            // BTR indicator (orange)
            Row(
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: const Color(0xFFFF9500), // Orange
                ),
                const SizedBox(width: 8),
                const Text(
                  'BTR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Second row: ATR and GTR
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ATR indicator (blue)
            Row(
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: const Color(0xFF007AFF), // Blue
                ),
                const SizedBox(width: 8),
                const Text(
                  'ATR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 24),
            
            // GTR indicator (red)
            Row(
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: const Color(0xFFFF3B30), // Red
                ),
                const SizedBox(width: 8),
                const Text(
                  'GTR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCenterContent() {
    // For relaxation meditation: always show only circle (no graphs even in debug mode)
    if (widget.meditationType == MeditationType.relaxation) {
      return Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          width: _currentCircleSize,
          height: _currentCircleSize,
          child: Image.asset(
            'assets/images/circle.png',
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    
    // For concentration meditation: show charts in debug mode
    if (kDebugMode) {
      // Debug mode: show circle + enhanced EEG chart side by side
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated circle image on the left
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            width: _currentCircleSize,
            height: _currentCircleSize,
            child: Image.asset(
              'assets/images/circle.png',
              fit: BoxFit.contain,
            ),
          ),
          
          // Enhanced EEG chart with legend on the right
          Column(
            children: [
              // EEG chart - bigger and wider with meditation mode
              const SizedBox(
                width: 350,
                child: EEGChart(
                  height: 250,
                  showGridLines: true,
                  showAxes: false,
                  chartMode: EEGChartMode.meditation,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Legend below the chart
              SizedBox(
                width: 350,
                child: _buildLegend(),
              ),
            ],
          ),
        ],
      );
    } else {
      // Normal mode: show only centered circle
      return Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          width: _currentCircleSize,
          height: _currentCircleSize,
          child: Image.asset(
            'assets/images/circle.png',
            fit: BoxFit.contain,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EEGDataProvider>(
      builder: (context, eegProvider, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                children: [
                  const Spacer(flex: 1),
                  
                  // Timer at top center
                  Text(
                    _formatTime(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Instructional text
                  Text(
                    widget.meditationType == MeditationType.concentration
                        ? 'Чем больше вы сконцентрированы, тем больше диаметр круга'
                        : 'Чем больше вы расслаблены, тем больше диаметр круга',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Center content - conditional rendering based on debug mode
                  _buildCenterContent(),
                  
                  const Spacer(flex: 2),
                  
                  // End meditation button at bottom
                  ElevatedButton(
                    onPressed: _endMeditation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Завершить медитацию',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
          // Electrode status widget in top left corner
          const ElectrodeStatusWidget(),
        ],
      ),
    );
  },
);
  }
} 