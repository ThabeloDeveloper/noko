import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nokofastfood/data/models/app_settings_model.dart';
import 'package:nokofastfood/constants/bottom_alert.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/models/delivery_route_model.dart';
import 'package:nokofastfood/data/models/order_model.dart';
import 'package:nokofastfood/data/models/promo_code_model.dart';
import 'package:nokofastfood/data/models/user_model.dart';
import 'package:nokofastfood/data/providers/cart_provider.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:nokofastfood/data/services/location_address_service.dart';
import 'package:nokofastfood/data/services/payment_service.dart';
import 'package:nokofastfood/pages/order_success_page.dart';
import 'package:nokofastfood/pages/peach_checkout_page.dart';
import 'package:provider/provider.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

enum FulfillmentType { delivery, collection }

enum CollectionType { takeAway, eatIn }

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();
  final TextEditingController _restaurantNoteController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final PaymentService _paymentService = PaymentService();
  final FirebaseService _firebaseService = FirebaseService();
  final LocationAddressService _locationService = LocationAddressService();

  PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;
  FulfillmentType _fulfillmentType = FulfillmentType.delivery;
  CollectionType _collectionType = CollectionType.takeAway;
  PromoCodeModel? _promoCode;
  bool _isLoading = false;
  bool _detectingAddress = false;
  bool _saveAddress = true;
  String? _coordinateAddress;
  double? _addressLatitude;
  double? _addressLongitude;

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (cart.items.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    if (user == null) {
      _showError('Please sign in before checkout.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final restaurantIds = cart.items.values
          .map((item) => item.product.restaurantId)
          .toSet();
      if (restaurantIds.length != 1) {
        throw Exception('Please order from one restaurant at a time.');
      }

      final restaurantId = restaurantIds.first;
      final restaurant = await _firebaseService.getRestaurant(restaurantId);
      if (restaurant != null && !restaurant.isOpen) {
        throw Exception('This restaurant is currently closed.');
      }

      final settings = await _firebaseService.getAppSettings();
      final isDelivery = _fulfillmentType == FulfillmentType.delivery;
      final deliveryFee = cart.deliveryFeeFor(
        delivery: isDelivery,
        configuredDeliveryFee: settings.deliveryFee,
      );
      final discount = (_promoCode?.discountFor(cart.subtotal) ?? 0).toDouble();
      final total = max(0.0, cart.subtotal - discount + deliveryFee);
      final deliveryAddress = isDelivery
          ? await _firebaseService.buildAddress(
              label: 'Delivery',
              address: _addressController.text.trim(),
              latitude: _usesDetectedCoordinates ? _addressLatitude : null,
              longitude: _usesDetectedCoordinates ? _addressLongitude : null,
              isDefault: _saveAddress,
            )
          : null;
      final route = isDelivery
          ? await _deliveryRouteFor(
              restaurantLatitude: restaurant?.latitude,
              restaurantLongitude: restaurant?.longitude,
              deliveryLatitude: deliveryAddress?.latitude,
              deliveryLongitude: deliveryAddress?.longitude,
            )
          : const DeliveryRouteModel(
              distanceMeters: 0,
              durationSeconds: 0,
              provider: 'collection',
              routePolyline: [],
            );
      if (isDelivery && route.distanceMeters > 25000) {
        throw Exception(
          'This address is ${route.distanceKilometres.toStringAsFixed(1)} km away by road, outside the 25 km delivery zone.',
        );
      }
      final paymentResult = await _paymentService.processPayment(
        amount: total,
        method: _paymentMethod,
      );

      final orderId = FirebaseFirestore.instance.collection('orders').doc().id;
      final order = OrderModel(
        id: orderId,
        orderNumber: _orderNumber(),
        customerId: user.uid,
        restaurantId: restaurantId,
        items: cart.items.values
            .map(
              (item) => {
                'productId': item.product.id,
                'name': item.product.name,
                'quantity': item.quantity,
                'price': item.product.price,
              },
            )
            .toList(),
        subtotal: cart.subtotal,
        deliveryFee: deliveryFee,
        total: total,
        fulfillmentType: isDelivery ? 'delivery' : 'collection',
        collectionType: isDelivery ? '' : _collectionType.code,
        status: 'pending',
        deliveryAddress:
            isDelivery ? deliveryAddress?.address ?? '' : 'Collection',
        deliveryLatitude: isDelivery ? deliveryAddress?.latitude : null,
        deliveryLongitude: isDelivery ? deliveryAddress?.longitude : null,
        paymentStatus: paymentResult.paymentStatus,
        paymentMethod: paymentResult.paymentMethod,
        verificationCode: _generateVerificationCode(),
        promoCode: _promoCode?.code,
        restaurantNote: _restaurantNoteController.text.trim(),
        discount: discount,
        etaMinutes: route.etaMinutes,
        routeDistanceMeters: route.distanceMeters,
        routeDurationSeconds: route.durationSeconds,
        routeProvider: route.provider,
        routePolyline: route.routePolyline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firebaseService.createOrder(order);

      if (isDelivery && _saveAddress && deliveryAddress != null) {
        await _firebaseService.saveAddress(user.uid, deliveryAddress);
      }

      if (_paymentMethod == PaymentMethod.peachPayments) {
        final session = await _firebaseService.createPeachCheckout(orderId);
        if (!mounted) return;
        final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PeachCheckoutPage(checkoutUrl: session.checkoutUrl),
          ),
        );
        final status = await _firebaseService.verifyPeachPayment(
          orderId: orderId,
          checkoutId: session.checkoutId,
        );
        if (!status.paid) {
          throw Exception(
            status.description.isEmpty
                ? 'Payment was not completed.'
                : status.description,
          );
        }
        if (completed != true && mounted) {
          _showError('Payment verified after returning from Peach.');
        }
      }

      cart.clear();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OrderSuccessPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(_checkoutErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyPromo(CartProvider cart) async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      _showError('Enter a promo code.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final promo = await _firebaseService.getPromoCode(code);
      final discount = promo?.discountFor(cart.subtotal) ?? 0;
      if (promo == null || discount <= 0) {
        throw Exception('Promo code is not valid for this order.');
      }
      setState(() => _promoCode = promo);
      _showSuccess('Promo applied.');
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _usesDetectedCoordinates =>
      _coordinateAddress != null &&
      _addressController.text.trim() == _coordinateAddress;

  Future<void> _detectAddress() async {
    setState(() => _detectingAddress = true);
    try {
      final detected = await _locationService.detectCurrentAddress();
      if (!mounted) return;
      _setAddress(
        detected.address,
        latitude: detected.latitude,
        longitude: detected.longitude,
      );
      _showSuccess('Delivery address detected.');
    } catch (e) {
      if (mounted) {
        _showError('$e');
      }
    } finally {
      if (mounted) {
        setState(() => _detectingAddress = false);
      }
    }
  }

  void _setAddress(String address, {double? latitude, double? longitude}) {
    setState(() {
      _addressController.text = address;
      _coordinateAddress = latitude != null && longitude != null
          ? address.trim()
          : null;
      _addressLatitude = latitude;
      _addressLongitude = longitude;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final isDelivery = _fulfillmentType == FulfillmentType.delivery;

    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Checkout',
          style: TextStyle(color: MyColors.primaryText),
        ),
        iconTheme: const IconThemeData(color: MyColors.primaryText),
      ),
      body: cart.items.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty',
                style: TextStyle(color: MyColors.secondaryText),
              ),
            )
          : StreamBuilder<AppSettingsModel>(
              stream: _firebaseService.watchAppSettings(),
              builder: (context, settingsSnapshot) {
                final settings =
                    settingsSnapshot.data ?? AppSettingsModel.defaults();
                final discount = _promoCode?.discountFor(cart.subtotal) ?? 0;
                final deliveryFee = cart.deliveryFeeFor(
                  delivery: isDelivery,
                  configuredDeliveryFee: settings.deliveryFee,
                );
                final total = max(0, cart.subtotal - discount + deliveryFee);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FulfillmentSelector(
                          value: _fulfillmentType,
                          deliveryFee: settings.deliveryFee,
                          onChanged: (value) =>
                              setState(() => _fulfillmentType = value),
                        ),
                        const SizedBox(height: 16),
                        if (isDelivery) ...[
                          if (user != null)
                            _savedAddressPicker(userId: user.uid),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            style: const TextStyle(
                              color: MyColors.primaryText,
                            ),
                            minLines: 2,
                            maxLines: 4,
                            decoration: _input('Delivery address'),
                            validator: (value) {
                              if (!isDelivery) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a delivery address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _detectingAddress ? null : _detectAddress,
                              icon: _detectingAddress
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_outlined),
                              label: Text(
                                _detectingAddress
                                    ? 'Detecting address...'
                                    : 'Use my current location',
                              ),
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _saveAddress,
                            onChanged: (value) =>
                                setState(() => _saveAddress = value ?? true),
                            title: const Text('Save this address'),
                          ),
                        ] else ...[
                          const _CollectionNotice(),
                          const SizedBox(height: 12),
                          _CollectionTypeSelector(
                            value: _collectionType,
                            onChanged: (value) =>
                                setState(() => _collectionType = value),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _PaymentSelector(
                          value: _paymentMethod,
                          fulfillmentType: _fulfillmentType,
                          onChanged: (value) =>
                              setState(() => _paymentMethod = value),
                        ),
                        const SizedBox(height: 16),
                        _RestaurantNotePanel(
                          controller: _restaurantNoteController,
                        ),
                        const SizedBox(height: 16),
                        _AvailablePromos(
                          service: _firebaseService,
                          subtotal: cart.subtotal,
                          onSelected: (code) {
                            _promoController.text = code;
                            _applyPromo(cart);
                          },
                        ),
                        const SizedBox(height: 16),
                        _PromoPanel(
                          controller: _promoController,
                          promoCode: _promoCode,
                          onApply: () => _applyPromo(cart),
                          onClear: () => setState(() => _promoCode = null),
                        ),
                        const SizedBox(height: 16),
                        _OrderSummary(
                          cart: cart,
                          discount: discount.toDouble(),
                          deliveryFee: deliveryFee,
                          fulfillmentType: _fulfillmentType,
                          total: total.toDouble(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _placeOrder,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _paymentMethod ==
                                            PaymentMethod.peachPayments
                                        ? 'Pay with Peach Payments'
                                        : 'Place Order',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _savedAddressPicker({required String userId}) {
    return StreamBuilder<UserModel?>(
      stream: _firebaseService.watchUser(userId),
      builder: (context, snapshot) {
        final addresses = snapshot.data?.savedAddresses ?? [];
        if (addresses.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved addresses',
              style: TextStyle(
                color: MyColors.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: addresses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  return ActionChip(
                    label: Text(
                      address.isDefault
                          ? '${address.label} (default)'
                          : address.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                    tooltip: address.address,
                    onPressed: () => _setAddress(
                      address.address,
                      latitude: address.latitude,
                      longitude: address.longitude,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: MyColors.surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showError(String message) {
    showAppBottomMessage(
      context,
      title: 'Checkout issue',
      message: message,
      type: BottomAlertType.error,
    );
  }

  void _showSuccess(String message) {
    showAppBottomMessage(
      context,
      title: 'Done',
      message: message,
      type: BottomAlertType.success,
    );
  }

  String _checkoutErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty && message != 'INTERNAL') {
        return message;
      }
      if (error.code == 'internal') {
        if (_paymentMethod == PaymentMethod.peachPayments) {
          return _fulfillmentType == FulfillmentType.collection
              ? 'Online payment could not start right now. Please choose Cash on collection and try again.'
              : 'Online payment could not start right now. Please choose Cash on delivery and try again.';
        }
        return 'Checkout could not be completed right now. Please try again.';
      }
      return 'Checkout could not be completed: ${error.code}.';
    }

    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  String _orderNumber() {
    final value = DateTime.now().millisecondsSinceEpoch.toString();
    return 'NK${value.substring(value.length - 10)}';
  }

  String _generateVerificationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<DeliveryRouteModel> _deliveryRouteFor({
    required double? restaurantLatitude,
    required double? restaurantLongitude,
    required double? deliveryLatitude,
    required double? deliveryLongitude,
  }) async {
    if (restaurantLatitude == null || restaurantLongitude == null) {
      throw Exception(
        'Restaurant coordinates are required before delivery can be calculated.',
      );
    }
    if (deliveryLatitude == null || deliveryLongitude == null) {
      throw Exception(
        'We could not find this delivery address on the map. Please enter a more specific address.',
      );
    }
    return _firebaseService.calculateDeliveryRoute(
      originLatitude: restaurantLatitude,
      originLongitude: restaurantLongitude,
      destinationLatitude: deliveryLatitude,
      destinationLongitude: deliveryLongitude,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _promoController.dispose();
    _restaurantNoteController.dispose();
    super.dispose();
  }
}

class _RestaurantNotePanel extends StatelessWidget {
  final TextEditingController controller;

  const _RestaurantNotePanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: MyColors.primaryText),
      minLines: 3,
      maxLines: 5,
      maxLength: 250,
      decoration: InputDecoration(
        labelText: 'Note for restaurant',
        hintText: 'Example: no onions, no chilli, sauce on the side',
        helperText: 'Optional. Tell the restaurant what to exclude or adjust.',
        filled: true,
        fillColor: MyColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

extension on CollectionType {
  String get code {
    switch (this) {
      case CollectionType.takeAway:
        return 'take_away';
      case CollectionType.eatIn:
        return 'eat_in';
    }
  }
}

class _AvailablePromos extends StatelessWidget {
  final FirebaseService service;
  final double subtotal;
  final ValueChanged<String> onSelected;

  const _AvailablePromos({
    required this.service,
    required this.subtotal,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoCodeModel>>(
      stream: service.getActivePromoCodes(),
      builder: (context, snapshot) {
        final promos = (snapshot.data ?? [])
            .where((promo) => promo.discountFor(subtotal) > 0)
            .toList();
        if (promos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available offers',
              style: TextStyle(
                color: MyColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: promos
                  .map(
                    (promo) => ActionChip(
                      avatar: const Icon(Icons.local_offer_outlined),
                      label: Text(promo.code),
                      onPressed: () => onSelected(promo.code),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _FulfillmentSelector extends StatelessWidget {
  final FulfillmentType value;
  final double deliveryFee;
  final ValueChanged<FulfillmentType> onChanged;

  const _FulfillmentSelector({
    required this.value,
    required this.deliveryFee,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order type',
          style: TextStyle(
            color: MyColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<FulfillmentType>(
          segments: [
            ButtonSegment(
              value: FulfillmentType.delivery,
              icon: const Icon(Icons.delivery_dining_outlined),
              label: Text('Delivery R${deliveryFee.toStringAsFixed(2)}'),
            ),
            const ButtonSegment(
              value: FulfillmentType.collection,
              icon: Icon(Icons.storefront_outlined),
              label: Text('Collection'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }
}

class _CollectionNotice extends StatelessWidget {
  const _CollectionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyColors.goldAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.goldAccent.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.store_mall_directory_outlined, color: MyColors.goldAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Collection orders have no delivery fee. We will prepare your food for pickup at the selected restaurant.',
              style: TextStyle(color: MyColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTypeSelector extends StatelessWidget {
  final CollectionType value;
  final ValueChanged<CollectionType> onChanged;

  const _CollectionTypeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collection option',
          style: TextStyle(
            color: MyColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<CollectionType>(
          segments: const [
            ButtonSegment(
              value: CollectionType.takeAway,
              icon: Icon(Icons.shopping_bag_outlined),
              label: Text('Take away'),
            ),
            ButtonSegment(
              value: CollectionType.eatIn,
              icon: Icon(Icons.restaurant_outlined),
              label: Text('Eat in'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  final PaymentMethod value;
  final FulfillmentType fulfillmentType;
  final ValueChanged<PaymentMethod> onChanged;

  const _PaymentSelector({
    required this.value,
    required this.fulfillmentType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment',
          style: TextStyle(
            color: MyColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<PaymentMethod>(
          segments: [
            ButtonSegment(
              value: PaymentMethod.cashOnDelivery,
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                fulfillmentType == FulfillmentType.collection
                    ? 'Cash on collection'
                    : 'Cash on delivery',
              ),
            ),
            const ButtonSegment(
              value: PaymentMethod.peachPayments,
              icon: Icon(Icons.credit_card_outlined),
              label: Text('Peach'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }
}

class _PromoPanel extends StatelessWidget {
  final TextEditingController controller;
  final PromoCodeModel? promoCode;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _PromoPanel({
    required this.controller,
    required this.promoCode,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: promoCode == null,
              decoration: const InputDecoration(
                labelText: 'Promo code',
                border: InputBorder.none,
              ),
            ),
          ),
          if (promoCode == null)
            OutlinedButton(onPressed: onApply, child: const Text('Apply'))
          else
            IconButton(
              tooltip: 'Remove promo',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final CartProvider cart;
  final double discount;
  final double deliveryFee;
  final FulfillmentType fulfillmentType;
  final double total;

  const _OrderSummary({
    required this.cart,
    required this.discount,
    required this.deliveryFee,
    required this.fulfillmentType,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ...cart.items.values.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}x ${item.product.name}',
                      style: const TextStyle(color: MyColors.secondaryText),
                    ),
                  ),
                  Text(
                    'R${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(color: MyColors.primaryText),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: MyColors.divider),
          _row('Subtotal', cart.subtotal),
          if (discount > 0) _row('Discount', -discount),
          _row(
            fulfillmentType == FulfillmentType.delivery
                ? 'Delivery fee'
                : 'Collection fee',
            deliveryFee,
          ),
          const Divider(color: MyColors.divider),
          _row('Total', total, totalRow: true),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {bool totalRow = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: totalRow ? MyColors.primaryText : MyColors.secondaryText,
              fontSize: totalRow ? 18 : 14,
              fontWeight: totalRow ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount < 0 ? '-' : ''}R${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: totalRow ? MyColors.goldAccent : MyColors.primaryText,
              fontSize: totalRow ? 18 : 14,
              fontWeight: totalRow ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
