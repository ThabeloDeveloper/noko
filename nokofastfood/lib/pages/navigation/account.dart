import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nokofastfood/constants/bottom_alert.dart';
import 'package:nokofastfood/constants/colors.dart';
import 'package:nokofastfood/data/models/product_model.dart';
import 'package:nokofastfood/data/models/user_model.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:nokofastfood/data/services/location_address_service.dart';
import 'package:nokofastfood/pages/landing.dart';
import 'package:nokofastfood/pages/product_detail.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseService _service = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        backgroundColor: MyColors.background,
        elevation: 0,
        title: Text(
          'Account',
          style: GoogleFonts.poppins(
            color: MyColors.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: currentUser == null
          ? _buildErrorState('User not logged in')
          : StreamBuilder<UserModel?>(
              stream: _service.watchUser(currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: MyColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  return _buildErrorState(
                    'An error occurred: ${snapshot.error}',
                  );
                }
                final user = snapshot.data;
                if (user == null) {
                  return _buildErrorState('User details not found');
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ProfileCard(user: user, onEdit: () => _editProfile(user)),
                    _AccountAction(
                      icon: Icons.lock_reset_outlined,
                      title: 'Send password reset email',
                      subtitle: user.email,
                      onTap: () => _sendPasswordReset(user.email),
                    ),
                    _AddressManager(user: user, service: _service),
                    _FavouritesPanel(user: user, service: _service),
                    const SizedBox(height: 18),
                    _logoutButton(),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _editProfile(UserModel user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user, service: _service),
    );
    if (saved == true && mounted) {
      _snack('Profile updated.');
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Password reset email sent.');
    } catch (e) {
      _snack('Could not send reset email: $e', error: true);
    }
  }

  Widget _logoutButton() {
    return OutlinedButton.icon(
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            CupertinoPageRoute(builder: (context) => const Landing()),
            (route) => false,
          );
        }
      },
      icon: const Icon(Icons.logout, color: MyColors.error),
      label: const Text('Logout'),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: MyColors.error, size: 60),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: MyColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            if (currentUser == null)
              FilledButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    CupertinoPageRoute(builder: (context) => const Landing()),
                    (route) => false,
                  );
                },
                child: const Text('Go to Landing Page'),
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    showAppBottomMessage(
      context,
      title: error ? 'Account issue' : 'Done',
      message: message,
      type: error ? BottomAlertType.error : BottomAlertType.success,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;

  const _ProfileCard({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: MyColors.primary,
                child: Text(
                  (user.name.isEmpty ? 'C' : user.name.characters.first)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? 'Customer' : user.name,
                      style: const TextStyle(
                        color: MyColors.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(color: MyColors.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const Divider(color: MyColors.divider, height: 28),
          _InfoRow(icon: Icons.phone_outlined, label: user.phone),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.badge_outlined, label: user.role.toUpperCase()),
        ],
      ),
    );
  }
}

class _AddressManager extends StatefulWidget {
  final UserModel user;
  final FirebaseService service;

  const _AddressManager({required this.user, required this.service});

  @override
  State<_AddressManager> createState() => _AddressManagerState();
}

class _AddressManagerState extends State<_AddressManager> {
  final _labelController = TextEditingController(text: 'Home');
  final _controller = TextEditingController();
  final _locationService = LocationAddressService();
  bool _saving = false;
  bool _detectingAddress = false;
  String? _coordinateAddress;
  double? _addressLatitude;
  double? _addressLongitude;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saved Addresses',
            style: TextStyle(
              color: MyColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (widget.user.savedAddresses.isEmpty)
            const Text(
              'No addresses saved yet.',
              style: TextStyle(color: MyColors.secondaryText),
            )
          else
            ...widget.user.savedAddresses.map(
              (address) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: MyColors.goldAccent,
                ),
                title: Text(address.label),
                subtitle: Text(address.address),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: address.isDefault
                          ? 'Default address'
                          : 'Set as default',
                      onPressed: address.isDefault
                          ? null
                          : () => widget.service.setDefaultAddress(
                              widget.user.id,
                              address,
                            ),
                      icon: Icon(
                        address.isDefault
                            ? Icons.star
                            : Icons.star_border_outlined,
                        color: MyColors.goldAccent,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove address',
                      onPressed: () =>
                          widget.service.removeAddress(widget.user.id, address),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Address label'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: 'New address'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _detectingAddress ? null : _detectAddress,
              icon: _detectingAddress
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined),
              label: Text(
                _detectingAddress
                    ? 'Detecting address...'
                    : 'Use current location',
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _usesDetectedCoordinates =>
      _coordinateAddress != null &&
      _controller.text.trim() == _coordinateAddress;

  Future<void> _detectAddress() async {
    setState(() => _detectingAddress = true);
    try {
      final detected = await _locationService.detectCurrentAddress();
      if (!mounted) return;
      setState(() {
        _controller.text = detected.address;
        _coordinateAddress = detected.address.trim();
        _addressLatitude = detected.latitude;
        _addressLongitude = detected.longitude;
      });
      showAppBottomMessage(
        context,
        title: 'Done',
        message: 'Address detected.',
        type: BottomAlertType.success,
      );
    } catch (e) {
      if (mounted) {
        showAppBottomMessage(
          context,
          title: 'Location issue',
          message: '$e',
          type: BottomAlertType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _detectingAddress = false);
      }
    }
  }

  Future<void> _save() async {
    final address = _controller.text.trim();
    if (address.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final savedAddress = await widget.service.buildAddress(
        label: _labelController.text,
        address: address,
        latitude: _usesDetectedCoordinates ? _addressLatitude : null,
        longitude: _usesDetectedCoordinates ? _addressLongitude : null,
        isDefault: widget.user.savedAddresses.isEmpty,
      );
      await widget.service.saveAddress(widget.user.id, savedAddress);
      _controller.clear();
      _coordinateAddress = null;
      _addressLatitude = null;
      _addressLongitude = null;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _FavouritesPanel extends StatelessWidget {
  final UserModel user;
  final FirebaseService service;

  const _FavouritesPanel({required this.user, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductModel>>(
      stream: service.getProducts(),
      builder: (context, snapshot) {
        final products = (snapshot.data ?? [])
            .where((product) => user.favoriteProductIds.contains(product.id))
            .toList();
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Favourites',
                style: TextStyle(
                  color: MyColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (products.isEmpty)
                const Text(
                  'Favourite items will appear here.',
                  style: TextStyle(color: MyColors.secondaryText),
                )
              else
                ...products.map(
                  (product) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: Text('R${product.price.toStringAsFixed(2)}'),
                    trailing: IconButton(
                      tooltip: 'Remove favourite',
                      onPressed: () => service.toggleFavorite(
                        uid: user.id,
                        productId: product.id,
                        isFavorite: true,
                      ),
                      icon: const Icon(Icons.favorite, color: MyColors.error),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(product: product),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final UserModel user;
  final FirebaseService service;

  const _EditProfileDialog({required this.user, required this.service});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _phone = TextEditingController(text: widget.user.phone);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MyColors.surfaceCard,
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateUserProfile(
        uid: widget.user.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }
}

class _AccountAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: MyColors.goldAccent),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MyColors.goldAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.isEmpty ? 'Not added' : label,
            style: const TextStyle(color: MyColors.secondaryText),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.divider),
      ),
      child: child,
    );
  }
}
