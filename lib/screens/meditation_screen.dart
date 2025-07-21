import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/eeg_chart.dart';
import '../providers/eeg_data_provider.dart';

/// Meditation screen with timer and visual elements
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  late Timer _timer;
  late Timer _animationTimer;
  int _seconds = 0;
  
  // Debug mode to control EEG chart visibility
  bool isDebugModeOn = true;
  
  // Pope value tracking for circle animation
  double? _baselinePope;
  double _currentCircleSize = 250.0;
  bool _isBaselineRecorded = false;

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
    final currentPope = _calculateCurrentPopeValue(eegProvider);
    
    // Record baseline Pope value on first calculation
    if (!_isBaselineRecorded && currentPope > 0.0) {
      _baselinePope = currentPope;
      _isBaselineRecorded = true;
    }
    
    // Update circle size if we have a baseline
    if (_isBaselineRecorded && _baselinePope != null) {
      final newSize = _calculateCircleSize(currentPope, _baselinePope!);
      if ((newSize - _currentCircleSize).abs() > 1.0) {
        setState(() {
          _currentCircleSize = newSize;
        });
      }
    }
  }

  double _calculateCurrentPopeValue(EEGDataProvider eegProvider) {
    final jsonSamples = eegProvider.dataProcessor.getLatestJsonSamples();
    
    if (jsonSamples.isEmpty) return 0.0;
    
    // Filter to last 10 seconds
    final cutoffTime = DateTime.now().millisecondsSinceEpoch - (10 * 1000);
    final recentSamples = jsonSamples.where((sample) => 
      sample.absoluteTimestamp.millisecondsSinceEpoch >= cutoffTime).toList();
    
    if (recentSamples.isEmpty) return 0.0;
    
    // Calculate 10-second moving average of beta / (theta + alpha)
    final popeValues = <double>[];
    for (final sample in recentSamples) {
      final thetaAlphaSum = sample.theta + sample.alpha;
      if (thetaAlphaSum != 0.0) {
        popeValues.add(sample.beta / thetaAlphaSum);
      }
    }
    
    return popeValues.isNotEmpty 
      ? popeValues.reduce((a, b) => a + b) / popeValues.length 
      : 0.0;
  }

  double _calculateCircleSize(double currentPope, double baselinePope) {
    const double baseSize = 250.0;
    const double maxSize = 500.0;
    const double minSize = 250.0;
    
    // Calculate proportional change
    final popeRatio = baselinePope != 0.0 ? currentPope / baselinePope : 1.0;
    final newSize = baseSize * popeRatio;
    
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
    if (isDebugModeOn) {
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
              'assets/circle.png',
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
            'assets/circle.png',
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
          body: SafeArea(
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
                  const Text(
                    'Чем больше вы расслабляетесь, тем больше диаметр круга',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
        );
      },
    );
  }
} 