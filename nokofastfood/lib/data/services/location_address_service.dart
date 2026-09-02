import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DetectedAddress {
  final String address;
  final double latitude;
  final double longitude;

  const DetectedAddress({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class LocationAddressService {
  Future<DetectedAddress> detectCurrentAddress() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Please turn on location services and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission is needed to detect your address.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is blocked. Open app settings and allow location access.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final placemarks = await Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) {
      throw Exception(
        'We found your location but could not turn it into an address.',
      );
    }

    return DetectedAddress(
      address: _formatAddress(placemarks.first),
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  String _formatAddress(Placemark place) {
    final parts =
        [
              place.street,
              place.subLocality,
              place.locality,
              place.administrativeArea,
              place.postalCode,
              place.country,
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

    final uniqueParts = <String>[];
    for (final part in parts) {
      if (!uniqueParts.contains(part)) {
        uniqueParts.add(part);
      }
    }

    return uniqueParts.join(', ');
  }
}
