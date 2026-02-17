import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final Position position;
  final String? address;

  LocationResult({required this.position, this.address});
}

class LocationService {
  Future<LocationResult?> fetchCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    String? address;
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.subLocality, p.locality, p.administrativeArea, p.country];
        address = parts
            .where((e) => e != null && e.isNotEmpty)
            .cast<String>()
            .join(', ');
      }
    } catch (e) {
      // Address fetching failed, but we have position
    }

    return LocationResult(position: position, address: address);
  }
}
