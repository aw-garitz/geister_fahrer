import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'recording_screen.dart';

class GhostSelectionScreen extends StatefulWidget {
  final bool startInEditMode; 
  const GhostSelectionScreen({super.key, this.startInEditMode = false});

  @override
  State<GhostSelectionScreen> createState() => _GhostSelectionScreenState();
}

class _GhostSelectionScreenState extends State<GhostSelectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tours = [];
  bool _isLoading = true;
  final Color ghostBlue = const Color(0xFF00B4FF);

  @override
  void initState() {
    super.initState();
    // Der TabController startet direkt im richtigen Modus
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.startInEditMode ? 1 : 0
    );
    _loadTours();
  }

  Future<void> _loadTours() async {
    final data = await DatabaseHelper().getAllTours();
    setState(() {
      _tours = data;
      _isLoading = false;
    });
  }

  // --- DIALOGE ---

  void _showRenameDialog(int id, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("TOUR UMBENENNEN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Neuer Name",
            labelStyle: TextStyle(color: ghostBlue),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ghostBlue)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ABBRECHEN", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().renameTour(id, controller.text);
              Navigator.pop(context);
              _loadTours();
            },
            child: Text("SPEICHERN", style: TextStyle(color: ghostBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("LÖSCHEN?", style: TextStyle(color: Colors.white)),
        content: const Text("Möchtest du diese Tour wirklich dauerhaft entfernen?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NEIN", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await DatabaseHelper().deleteTour(id);
              Navigator.pop(context);
              _loadTours();
            },
            child: const Text("JA, LÖSCHEN", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStartConfirmDialog(Map<String, dynamic> tour) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.all(25),
        title: Text(
          "RENNEN STARTEN GEGEN:\n${tour['name'].toUpperCase()}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 100,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordingScreen(ghostTourId: tour['id']),
                    ),
                  );
                },
                child: const Text("START", style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ZURÜCK", style: TextStyle(color: Colors.white38, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // --- LISTEL-ANSICHTEN ---

  // MODUS 1: RENNEN (Gegen Geist)
  Widget _buildRaceList() {
    return ListView.builder(
      itemCount: _tours.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemBuilder: (context, index) {
        final tour = _tours[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: InkWell(
            onTap: () => _showStartConfirmDialog(tour),
            borderRadius: BorderRadius.circular(25),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: ghostBlue.withOpacity(0.3), width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: ghostBlue.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(23), bottomLeft: Radius.circular(23)),
                    ),
                    child: Icon(Icons.bolt, color: ghostBlue, size: 45),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        tour['name'].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 50),
                  const SizedBox(width: 15),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // MODUS 2: VERWALTEN (Meine Touren)
  Widget _buildAdminList() {
    return ListView.builder(
      itemCount: _tours.length,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemBuilder: (context, index) {
        final tour = _tours[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(tour['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(tour['date'].toString().substring(0, 10), style: const TextStyle(color: Colors.white38)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white54),
                  onPressed: () => _showRenameDialog(tour['id'], tour['name']),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(tour['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.startInEditMode ? "MEINE TOUREN" : "GEGEN GEIST", 
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ghostBlue,
          indicatorWeight: 4,
          tabs: const [
            Tab(text: "RENNEN"),
            Tab(text: "VERWALTEN"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: ghostBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRaceList(),
                _buildAdminList(),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}