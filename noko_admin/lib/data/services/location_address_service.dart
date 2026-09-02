import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DetectedAddress {
  final String address;
  final String locationLabel;
  final double latitude;
  final double longitude;

  const DetectedAddress({
    required this.address,
    required this.locationLabel,
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
      throw Exception('Location permission is needed to detect this address.');
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
        'We found the location but could not turn it into an address.',
      );
    }

    final place = placemarks.first;
    return DetectedAddress(
      address: _formatAddress(place),
      locationLabel: _formatLocationLabel(place),
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  String _formatAddress(Placemark place) {
    return _uniqueParts([
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ]).join(', ');
  }

  String _formatLocationLabel(Placemark place) {
    final parts = _uniqueParts([
      place.subLocality,
      place.locality,
      place.administrativeArea,
    ]);
    return parts.isEmpty ? _formatAddress(place) : parts.join(', ');
  }

  List<String> _uniqueParts(List<String?> values) {
    final parts = values
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
    return uniqueParts;
  }
}
