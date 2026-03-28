import 'package:flutter/material.dart';
import '../database_helper.dart'; // Pfad ggf. an dein Projekt anpassen
import 'recording_screen.dart';

class GhostSelectionScreen extends StatefulWidget {
  const GhostSelectionScreen({super.key});

  @override
  State<GhostSelectionScreen> createState() => _GhostSelectionScreenState();
}

class _GhostSelectionScreenState extends State<GhostSelectionScreen> {
  final Color ghostBlue = const Color(0xFF00B4FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Passend zum MainDashboard
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "GEIST WÄHLEN",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getAllTours(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: ghostBlue));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          // SORTIER-LOGIK: Favoriten zuerst, dann nach Datum
          final tours = List<Map<String, dynamic>>.from(snapshot.data!);
          tours.sort((a, b) {
            int favA = a['is_favorite'] ?? 0;
            int favB = b['is_favorite'] ?? 0;
            if (favA != favB) return favB.compareTo(favA);
            return b['date'].toString().compareTo(a['date'].toString());
          });

          return ListView.builder(
            itemCount: tours.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final tour = tours[index];
              final bool isFav = tour['is_favorite'] == 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFav ? ghostBlue.withOpacity(0.6) : Colors.white10,
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isFav ? ghostBlue.withOpacity(0.2) : Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFav ? Icons.star : Icons.directions_bike,
                      color: isFav ? Colors.yellowAccent : ghostBlue,
                    ),
                  ),
                  title: Text(
                    tour['name'] ?? "Unbenannte Tour",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    "Datum: ${tour['date'].toString().substring(0, 10)}",
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FAVORITEN-BUTTON
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.yellowAccent : Colors.white30,
                        ),
                        onPressed: () async {
                          await DatabaseHelper().updateFavorite(
                            tour['id'], 
                            isFav ? 0 : 1
                          );
                          setState(() {}); // UI Refresh
                        },
                      ),
                      // LÖSCH-BUTTON
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(tour['id'], tour['name'] ?? "Tour"),
                      ),
                    ],
                  ),
                  onTap: () {
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.white10),
          const SizedBox(height: 20),
          const Text(
            "Noch keine Geister vorhanden.\nZeichne erst eine Strecke auf!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Geist löschen?", style: TextStyle(color: Colors.white)),
        content: Text("Möchtest du '$name' wirklich löschen?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Abbrechen", style: TextStyle(color: Colors.white30))
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().deleteTour(id);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Löschen", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}