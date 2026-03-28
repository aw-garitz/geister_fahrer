import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import 'recording_screen.dart';
import 'ghost_selection_screen.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Wir nutzen das Electric Blue aus dem Logo als Hauptakzent
    const Color ghostBlue = Color(0xFF00B4FF); 

    return Scaffold(
      backgroundColor: Colors.black, // Maximaler Kontrast für das OLED
      body: Stack(
        children: [
          // Subtiler Hintergrund-Gradient für Tiefe
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ghostBlue.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Header mit Barometer-Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GEISTER",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              height: 0.9,
                            ),
                          ),
                          Text(
                            "FAHRER",
                            style: TextStyle(
                              color: ghostBlue,
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 10,
                            ),
                          ),
                        ],
                      ),
                      // Barometer-Icon (funktional & schick)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          SensorService().isBarometerAvailable 
                            ? Icons.height 
                            : Icons.height_outlined,
                          color: SensorService().isBarometerAvailable ? Colors.cyanAccent : Colors.grey,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Die Buttons im neuen Vektor-Style
                  _DashboardButton(
                    title: 'FREIE FAHRT',
                    subtitle: 'Neue Strecke erkunden',
                    icon: Icons.add_location_alt_outlined,
                    color: Colors.white,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RecordingScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DashboardButton(
                    title: 'GEGEN GEIST',
                    subtitle: 'Schlag deine Bestzeit',
                    icon: Icons.directions_bike,
                    color: ghostBlue,
                    isGhostMode: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GhostSelectionScreen()),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isGhostMode;

  const _DashboardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isGhostMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isGhostMode ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isGhostMode ? [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: color.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}