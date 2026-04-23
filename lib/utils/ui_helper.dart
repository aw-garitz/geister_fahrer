import 'package:flutter/material.dart';

class UIHelper {
  // Gibt die Gerätebreite zurück
  static double deviceWidth(BuildContext context) => MediaQuery.of(context).size.width;

  // Gibt die Gerätehöhe zurück
  static double deviceHeight(BuildContext context) => MediaQuery.of(context).size.height;

  // Prozentuale Abstände (z.B. 0.05 für 5% der Bildschirmhöhe)
  static double verticalSpace(BuildContext context, double percent) => 
      deviceHeight(context) * percent;

  static double horizontalSpace(BuildContext context, double percent) => 
      deviceWidth(context) * percent;

  // Dynamische Schriftgrößen (basierend auf der Breite, damit Text nicht umbricht)
  static double dynamicFontSize(BuildContext context, double percent) => 
      deviceWidth(context) * percent;

  // Gibt das passende Icon für die Fortbewegungsart zurück
  static IconData getActivityIcon(String? type) {
    switch (type) {
      case 'run': return Icons.directions_run;
      case 'car': return Icons.directions_car;
      default: return Icons.directions_bike;
    }
  }
}