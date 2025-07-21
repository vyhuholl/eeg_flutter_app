import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/eeg_chart.dart';

/// Meditation screen with timer and visual elements
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  late Timer _timer;
  int _seconds = 0;
  
  // Debug mode to control EEG chart visibility
  bool isDebugModeOn = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
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
          // Circle image on the left
          Image.asset(
            'assets/circle.png',
            width: 280,
            height: 280,
            fit: BoxFit.contain,
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
        child: Image.asset(
          'assets/circle.png',
          width: 400,
          height: 400,
          fit: BoxFit.contain,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
  }
} 