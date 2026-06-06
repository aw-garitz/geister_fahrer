import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color ghostBlue = Color(0xFF00B4FF);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("DATENSCHUTZ", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection("1. Datenerfassung", 
                "Geisterfahrer erfasst GPS-Standortdaten, um deine Touren aufzuzeichnen und den Vergleich mit 'Geistern' zu ermöglichen. Diese Daten werden lokal auf deinem Gerät in einer Datenbank gespeichert."),
              _buildSection("2. Hintergrund-Standort", 
                "Um Touren auch bei ausgeschaltetem Bildschirm lückenlos aufzuzeichnen, fordert die App Zugriff auf den Standort im Hintergrund an."),
              _buildSection("3. Google AdMob", 
                "Diese App nutzt Google AdMob zur Anzeige von Werbung. Google verwendet IDs für Werbezwecke (z. B. die Werbe-ID), um Anzeigen zu personalisieren und Statistiken zu erstellen."),
              _buildSection("4. Speicherort", 
                "Alle aufgezeichneten Fahrten verbleiben auf deinem Gerät, sofern du keine externe Backup-Funktion deines Betriebssystems nutzt."),
              const SizedBox(height: 30),
              const Text("Stand: Oktober 2023", style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF00B4FF), fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}