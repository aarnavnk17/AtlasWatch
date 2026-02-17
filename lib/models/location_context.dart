// ===============================
// LOCATION CONTEXT MODEL
// ===============================
// Frontend-only abstraction of user location
// ===============================

import 'risk_level.dart';

enum LocationContext { cityCenter, touristArea, remoteArea, unsafeArea }

extension LocationContextExtension on LocationContext {
  RiskLevel get riskLevel {
    switch (this) {
      case LocationContext.unsafeArea:
        return RiskLevel.high;
      case LocationContext.remoteArea:
        return RiskLevel.medium;
      case LocationContext.touristArea:
        return RiskLevel.low;
      case LocationContext.cityCenter:
        return RiskLevel.low;
    }
  }

  String get label {
    switch (this) {
      case LocationContext.cityCenter:
        return 'City Center';
      case LocationContext.touristArea:
        return 'Tourist Area';
      case LocationContext.remoteArea:
        return 'Remote Area';
      case LocationContext.unsafeArea:
        return 'Unsafe Area';
    }
  }
}
