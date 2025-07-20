import 'dart:async';
import 'package:flutter/material.dart';

/// Meditation screen with timer and visual elements
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  late Timer _timer;
  int _seconds = 0;

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
              
              // Circle image at center
              Center(
                child: Image.asset(
                  'assets/circle.png',
                  width: 400,
                  height: 400,
                  fit: BoxFit.contain,
                ),
              ),
              
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