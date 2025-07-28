import 'package:flutter/material.dart';
import '../widgets/electrode_status_widget.dart';
import 'meditation_screen.dart';

/// Enumeration for meditation types
enum MeditationType {
  concentration,
  relaxation,
}

/// Screen for selecting meditation type (concentration or relaxation)
class MeditationSelectionScreen extends StatelessWidget {
  const MeditationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Выберите тип медитации',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Relaxation button (green)
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () => _startMeditation(context, MeditationType.relaxation),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32D74B), // Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Расслабление',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Concentration button (violet)
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () => _startMeditation(context, MeditationType.concentration),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBF5AF2), // Violet
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Концентрация',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Back button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Назад',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Electrode status widget in top left corner
      const ElectrodeStatusWidget(),
    ],
  ),
);
  }

  void _startMeditation(BuildContext context, MeditationType type) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MeditationScreen(meditationType: type),
      ),
    );
  }
} 