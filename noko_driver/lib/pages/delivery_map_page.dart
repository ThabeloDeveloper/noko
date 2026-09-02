import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:noko_driver/constants/colors.dart';
import 'package:noko_driver/data/models/driver_order.dart';
import 'package:noko_driver/data/models/restaurant.dart';
import 'package:noko_driver/data/services/firebase_service.dart';

class DeliveryMapPage extends StatelessWidget {
  final String orderId;

  const DeliveryMapPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return StreamBuilder<DriverOrder?>(
      stream: service.watchOrder(orderId),
      builder: (context, orderSnapshot) {
        final order = orderSnapshot.data;
        if (order == null) {
          return const Scaffold(
            backgroundColor: MyColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return FutureBuilder<Restaurant?>(
          future: service.getRestaurant(order.restaurantId),
          builder: (context, restaurantSnapshot) {
            return _Map(order: order, restaurant: restaurantSnapshot.data);
          },
        );
      },
    );
  }
}

class _Map extends StatelessWidget {
  final DriverOrder order;
  final Restaurant? restaurant;

  const _Map({required this.order, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final pickup = restaurant?.latitude == null || restaurant?.longitude == null
        ? null
        : LatLng(restaurant!.latitude!, restaurant!.longitude!);
    final dropoff =
        order.deliveryLatitude == null || order.deliveryLongitude == null
        ? null
        : LatLng(order.deliveryLatitude!, order.deliveryLongitude!);
    final driver = order.driverLatitude == null || order.driverLongitude == null
        ? null
        : LatLng(order.driverLatitude!, order.driverLongitude!);
    final center = driver ?? pickup ?? dropoff;
    final storedRoute = order.routePolyline
        .map((point) {
          final lat = point['latitude'];
          final lng = point['longitude'];
          if (lat is num && lng is num) {
            return LatLng(lat.toDouble(), lng.toDouble());
          }
          return null;
        })
        .nonNulls
        .toList();
    final points = storedRoute.isNotEmpty
        ? storedRoute
        : [pickup, driver, dropoff].nonNulls.toList();

    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: const Text('Route Map'),
        backgroundColor: MyColors.primary,
      ),
      body: center == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No coordinates yet. Add restaurant and delivery coordinates, then share driver location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MyColors.secondaryText),
                ),
              ),
            )
          : FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.noko.driver',
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: MyColors.primary,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (pickup != null)
                      _marker(pickup, Icons.storefront, MyColors.goldAccent),
                    if (driver != null)
                      _marker(driver, Icons.delivery_dining, MyColors.primary),
                    if (dropoff != null)
                      _marker(dropoff, Icons.home_outlined, MyColors.success),
                  ],
                ),
              ],
            ),
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
