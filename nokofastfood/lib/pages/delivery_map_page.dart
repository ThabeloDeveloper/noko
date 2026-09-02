import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/models/order_model.dart';
import 'package:nokofastfood/data/models/restaurant_model.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryMapPage extends StatelessWidget {
  final String orderId;

  const DeliveryMapPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    return StreamBuilder<OrderModel?>(
      stream: service.watchOrder(orderId),
      builder: (context, orderSnapshot) {
        final order = orderSnapshot.data;
        if (order == null) {
          return const Scaffold(
            backgroundColor: MyColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return FutureBuilder<RestaurantModel?>(
          future: service.getRestaurant(order.restaurantId),
          builder: (context, restaurantSnapshot) {
            return _DeliveryMapView(
              order: order,
              restaurant: restaurantSnapshot.data,
            );
          },
        );
      },
    );
  }
}

class _DeliveryMapView extends StatefulWidget {
  final OrderModel order;
  final RestaurantModel? restaurant;

  const _DeliveryMapView({required this.order, required this.restaurant});

  @override
  State<_DeliveryMapView> createState() => _DeliveryMapViewState();
}

class _DeliveryMapViewState extends State<_DeliveryMapView> {
  LatLng? _restaurantPoint;
  LatLng? _deliveryPoint;
  bool _loading = true;

  LatLng? get _driverPoint {
    final lat = widget.order.driverLatitude;
    final lng = widget.order.driverLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    _resolvePoints();
  }

  @override
  void didUpdateWidget(covariant _DeliveryMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.deliveryAddress != widget.order.deliveryAddress ||
        oldWidget.restaurant?.id != widget.restaurant?.id) {
      _resolvePoints();
    }
  }

  Future<void> _resolvePoints() async {
    setState(() => _loading = true);
    final restaurant = widget.restaurant;
    final resolvedRestaurant = restaurant == null
        ? null
        : await _pointFrom(
            lat: restaurant.latitude,
            lng: restaurant.longitude,
            address: restaurant.address.isNotEmpty
                ? restaurant.address
                : restaurant.location,
          );
    final resolvedDelivery = await _pointFrom(
      lat: widget.order.deliveryLatitude,
      lng: widget.order.deliveryLongitude,
      address: widget.order.deliveryAddress,
    );
    if (!mounted) return;
    setState(() {
      _restaurantPoint = resolvedRestaurant;
      _deliveryPoint = resolvedDelivery;
      _loading = false;
    });
  }

  Future<LatLng?> _pointFrom({
    required double? lat,
    required double? lng,
    required String address,
  }) async {
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    if (address.trim().isEmpty) {
      return null;
    }
    try {
      final locations = await Geocoding().locationFromAddress(address);
      if (locations.isEmpty) {
        return null;
      }
      return LatLng(locations.first.latitude, locations.first.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _driverPoint ?? _deliveryPoint ?? _restaurantPoint;
    final markers = <Marker>[
      ...?(_restaurantPoint == null
          ? null
          : [
              _marker(_restaurantPoint!, Icons.storefront, MyColors.goldAccent),
            ]),
      ...?(_driverPoint == null
          ? null
          : [_marker(_driverPoint!, Icons.delivery_dining, MyColors.primary)]),
      ...?(_deliveryPoint == null
          ? null
          : [_marker(_deliveryPoint!, Icons.home_outlined, MyColors.success)]),
    ];
    final route = [
      if (_storedRoute.isNotEmpty)
        ..._storedRoute
      else ...[
        _restaurantPoint,
        _driverPoint,
        _deliveryPoint,
      ].nonNulls,
    ];

    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: const Text('Live Delivery Map'),
        backgroundColor: MyColors.background,
        iconTheme: const IconThemeData(color: MyColors.primaryText),
      ),
      body: center == null
          ? _emptyState()
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 13),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.noko.nokofastfood',
                    ),
                    if (route.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route,
                            color: MyColors.goldAccent,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                if (_loading) const LinearProgressIndicator(),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _TrackingCard(
                    order: widget.order,
                    restaurant: widget.restaurant,
                    driverPoint: _driverPoint,
                    deliveryPoint: _deliveryPoint,
                    onOpenMaps: _deliveryPoint == null
                        ? null
                        : () => _openExternalMap(_deliveryPoint!),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Map coordinates are not available yet. Add coordinates to the restaurant and delivery address to enable live tracking.',
          textAlign: TextAlign.center,
          style: TextStyle(color: MyColors.secondaryText),
        ),
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

  Future<void> _openExternalMap(LatLng point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<LatLng> get _storedRoute {
    return widget.order.routePolyline
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
  }
}

class _TrackingCard extends StatelessWidget {
  final OrderModel order;
  final RestaurantModel? restaurant;
  final LatLng? driverPoint;
  final LatLng? deliveryPoint;
  final VoidCallback? onOpenMaps;

  const _TrackingCard({
    required this.order,
    required this.restaurant,
    required this.driverPoint,
    required this.deliveryPoint,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final eta = _etaText();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MyColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurant?.name ?? 'Restaurant',
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Chip(label: Text(_label(order.status))),
            ],
          ),
          const SizedBox(height: 8),
          Text(eta, style: const TextStyle(color: MyColors.secondaryText)),
          if (order.routeDistanceMeters != null) ...[
            const SizedBox(height: 4),
            Text(
              'Road distance: ${(order.routeDistanceMeters! / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(color: MyColors.secondaryText),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.deliveryAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MyColors.secondaryText),
                ),
              ),
              IconButton(
                tooltip: 'Open in maps',
                onPressed: onOpenMaps,
                icon: const Icon(Icons.map_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _etaText() {
    if (order.status == 'delivered') return 'Delivered';
    if (order.status == 'cancelled') return 'Cancelled';
    if (driverPoint == null || deliveryPoint == null) {
      return 'Estimated delivery: about ${order.etaMinutes} minutes';
    }
    final kilometres = const Distance().as(
      LengthUnit.Kilometer,
      driverPoint!,
      deliveryPoint!,
    );
    final minutes = (kilometres / 28 * 60).clamp(5, 120).round();
    return 'Driver is ${kilometres.toStringAsFixed(1)} km away, about $minutes minutes';
  }

  String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
