import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';


class SensorService {
  // Wir machen daraus ein Singleton, damit wir überall 
  // in der App auf denselben Status zugreifen.
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  bool _isBarometerAvailable = false;
  bool get isBarometerAvailable => _isBarometerAvailable;

  /// Diese Methode wird einmal beim App-Start aufgerufen
  Future<void> checkSensors() async {
    try {
      // Wir prüfen kurz, ob ein Barometer-Event ankommt
      // Ein Timeout von 500ms reicht völlig aus.
      final event = await barometerEventStream().first.timeout(
  const Duration(milliseconds: 500),
);
      _isBarometerAvailable = (event != null);
    } catch (e) {
      _isBarometerAvailable = false;
    }
  }
}