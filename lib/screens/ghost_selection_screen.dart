import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'recording_screen.dart';
import 'tour_detail_screen.dart';
import '../utils/ui_helper.dart';

class GhostSelectionScreen extends StatefulWidget {
  final bool startInEditMode; 
  // startInEditMode = true  -> Tab "VERWALTEN" ist aktiv
  // startInEditMode = false -> Tab "RENNEN" ist aktiv
  const GhostSelectionScreen({super.key, this.startInEditMode = false});

  @override
  State<GhostSelectionScreen> createState() => _GhostSelectionScreenState();
}

class _GhostSelectionScreenState extends State<GhostSelectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tours = [];
  bool _isLoading = true;
  final Color ghostBlue = const Color(0xFF00B4FF);
  final Color userNeonGreen = const Color(0xFF00FF00);

  String _activityFilter = 'all'; // 'all', 'bike', 'run', 'car'
  bool _sortAscending = false; // false = neueste zuerst (desc)

  @override
  void initState() {
    super.initState();
    // Hier wird entschieden, welcher Tab beim Start offen ist:
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

  // Hilfsmethode zum Filtern und Sortieren der geladenen Daten
  List<Map<String, dynamic>> get _filteredAndSortedTours {
    List<Map<String, dynamic>> list = List.from(_tours);

    // 1. Filtern
    if (_activityFilter != 'all') {
      list = list.where((t) => t['activity_type'] == _activityFilter).toList();
    }

    // 2. Sortieren
    list.sort((a, b) {
      // Favoriten immer zuerst
      if (a['is_favorite'] != b['is_favorite']) {
        return b['is_favorite'].compareTo(a['is_favorite']);
      }
      
      // Danach nach Datum
      DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
      DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
      
      return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return list;
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          _buildFilterChip('all', Icons.filter_list, "ALLE"),
          _buildFilterChip('bike', Icons.directions_bike, null),
          _buildFilterChip('run', Icons.directions_run, null),
          _buildFilterChip('car', Icons.directions_car, null),
          const Spacer(),
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: ghostBlue,
              size: 20,
            ),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            tooltip: "Datum sortieren",
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, IconData icon, String? label) {
    bool isSelected = _activityFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _activityFilter = type),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ghostBlue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ghostBlue : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? ghostBlue : Colors.white38),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? ghostBlue : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- DIALOGE ---

  void _showRenameDialog(int id, String currentName, String currentActivity) {
    TextEditingController controller = TextEditingController(text: currentName);
    String selectedActivity = currentActivity;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget buildActivityIcon(String type, IconData icon) {
            bool isSelected = selectedActivity == type;
            return GestureDetector(
              onTap: () => setDialogState(() => selectedActivity = type),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? userNeonGreen : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isSelected ? Colors.black : Colors.white),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: ghostBlue, width: 1),
            ),
            title: const Text("TOUR BEARBEITEN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildActivityIcon('bike', Icons.directions_bike),
                    buildActivityIcon('run', Icons.directions_run),
                    buildActivityIcon('car', Icons.directions_car),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Name der Tour",
                    labelStyle: TextStyle(color: ghostBlue),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ghostBlue)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("ABBRECHEN", style: TextStyle(color: Colors.white54))),
              TextButton(
                onPressed: () async {
                  await DatabaseHelper().updateTourMetadata(id, controller.text, selectedActivity);
                  Navigator.pop(context);
                  _loadTours();
                },
                child: Text("SPEICHERN", style: TextStyle(color: ghostBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _reverseTour(Map<String, dynamic> tour) async {
    setState(() => _isLoading = true);
    try {
      final int tourId = tour['id'];
      final List<Map<String, dynamic>> originalPoints = await DatabaseHelper().getTourPoints(tourId);
      
      if (originalPoints.isEmpty) return;

      // 1. Punkte umkehren
      List<Map<String, dynamic>> reversedPoints = List.from(originalPoints.reversed);

      // 2. Zeitstempel anpassen (Intervalle beibehalten)
      DateTime startTime = DateTime.parse(originalPoints.first['timestamp']);
      List<Map<String, dynamic>> newPoints = [];
      DateTime currentTimestamp = startTime;

      for (int i = 0; i < reversedPoints.length; i++) {
        Map<String, dynamic> p = Map.from(reversedPoints[i]);
        p['timestamp'] = currentTimestamp.toIso8601String();
        newPoints.add(p);

        if (i < reversedPoints.length - 1) {
          // Intervall aus der Original-Reihenfolge nehmen
          DateTime tCurrentOrig = DateTime.parse(originalPoints[originalPoints.length - 1 - i]['timestamp']);
          DateTime tNextOrig = DateTime.parse(originalPoints[originalPoints.length - 2 - i]['timestamp']);
          currentTimestamp = currentTimestamp.add(tCurrentOrig.difference(tNextOrig));
        }
      }

      // 3. Als neue Tour speichern
      String newName = "${tour['name']} (UMGEKEHRT)";
      await DatabaseHelper().saveTour(newName, tour['activity_type'] ?? 'bike', newPoints);
    } finally {
      _loadTours();
    }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: ghostBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.all(25),
        title: Text(
          "RENNEN STARTEN GEGEN:\n${tour['name'].toUpperCase()}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${tour['distance'] ?? '--'}  |  ${tour['duration'] ?? '--'}", 
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 80,
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
                child: const Text("START", style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold)),
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

  // --- LISTEN ---

  Widget _buildRaceList() {
    final filteredList = _filteredAndSortedTours;
    if (filteredList.isEmpty) return const Center(child: Text("KEINE TOUREN GEFUNDEN", style: TextStyle(color: Colors.white24)));
    return ListView.builder(
      itemCount: filteredList.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemBuilder: (context, index) {
        final tour = filteredList[index];
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
                    child: Icon(UIHelper.getActivityIcon(tour['activity_type']), color: ghostBlue, size: 45),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tour['name'].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text("${tour['distance'] ?? '--'} • ${tour['duration'] ?? '--'}", style: const TextStyle(color: Colors.white38, fontSize: 14)),
                        ],
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

  Widget _buildAdminList() {
    final filteredList = _filteredAndSortedTours;
    if (filteredList.isEmpty) return const Center(child: Text("LISTE LEER", style: TextStyle(color: Colors.white24)));
    return ListView.builder(
      itemCount: filteredList.length,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemBuilder: (context, index) {
        final tour = filteredList[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => TourDetailScreen(tourId: tour['id'])));
            },
            leading: Icon(UIHelper.getActivityIcon(tour['activity_type']), color: Colors.white70),
            title: Text(tour['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("${tour['date']?.toString().substring(0,10) ?? ''} • ${tour['distance'] ?? ''}", style: const TextStyle(color: Colors.white38)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.swap_vert, color: Colors.blueAccent), 
                  onPressed: () => _reverseTour(tour),
                  tooltip: "Tour umkehren",
                ),
                IconButton(icon: const Icon(Icons.edit, color: Colors.white54), onPressed: () => _showRenameDialog(tour['id'], tour['name'], tour['activity_type'] ?? 'bike')),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _confirmDelete(tour['id'])),
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
        title: Text(widget.startInEditMode ? "MEINE TOUREN" : "GEGEN GEIST", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ghostBlue,
          tabs: const [ Tab(text: "RENNEN"), Tab(text: "VERWALTEN") ],
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: ghostBlue)) 
        : Column(
            children: [
              _buildFilterBar(), // Hier wird die Filter-Leiste eingefügt
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [ _buildRaceList(), _buildAdminList() ],
                ),
              ),
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