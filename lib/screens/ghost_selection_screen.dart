import 'package:flutter/material.dart';
import 'package:ghost_ride/database_helper.dart';

import 'recording_screen.dart';

class GhostSelectionScreen extends StatefulWidget {
  const GhostSelectionScreen({super.key});

  @override
  State<GhostSelectionScreen> createState() => _GhostSelectionScreenState();
}

class _GhostSelectionScreenState extends State<GhostSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GEIST WÄHLEN"),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getAllTours(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Noch keine Fahrten vorhanden.\nZeichne erst eine Strecke auf!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final tours = snapshot.data!;

          return ListView.builder(
            itemCount: tours.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final tour = tours[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.history, color: Colors.white),
                  ),
                  title: Text(
                    tour['name'] ?? "Unbenannte Tour",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Datum: ${tour['date'].toString().substring(0, 10)}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(tour['id'], tour['name']),
                  ),
                  onTap: () {
                    // WICHTIG: Hier übergeben wir die ID an den RecordingScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecordingScreen(ghostTourId: tour['id']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Löschen?"),
        content: Text("Möchtest du '$name' wirklich löschen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().deleteTour(id);
              Navigator.pop(context);
              setState(() {}); // Liste aktualisieren
            },
            child: const Text("Löschen", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}