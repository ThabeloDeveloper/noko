import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/bottom_alert.dart';
import '../constants/colors.dart';
import '../data/models/product_model.dart';
import '../data/models/restaurant_model.dart';
import '../data/models/review_model.dart';
import '../data/providers/cart_provider.dart';
import '../data/services/firebase_service.dart';
import 'auth/sign_in.dart';
import 'auth/sign_up.dart';

class ProductDetailPage extends StatelessWidget {
  final ProductModel product;
  final RestaurantModel? restaurant;

  const ProductDetailPage({super.key, required this.product, this.restaurant});

  Future<void> _handleAddToCart(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSignInRequired(context);
      return;
    }

    final cart = context.read<CartProvider>();
    final existingRestaurantIds = cart.items.values
        .map((item) => item.product.restaurantId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (existingRestaurantIds.isNotEmpty &&
        !existingRestaurantIds.contains(product.restaurantId)) {
      final replace = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _CartReplaceSheet(),
      );
      if (replace != true) {
        return;
      }
      if (!context.mounted) return;
      cart.clear();
    }

    cart.addItem(product);
    showAppBottomMessage(
      context,
      title: 'Added to cart',
      message: '${product.name} added to cart',
      type: BottomAlertType.success,
    );
  }

  void _showSignInRequired(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SignInRequiredSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: MyColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: MyColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProductImage(url: product.imageUrl),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (user != null)
                _FavouriteAction(userId: user.uid, productId: product.id),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            color: MyColors.primaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'R${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: MyColors.goldAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant?.name ?? product.category,
                    style: const TextStyle(
                      color: MyColors.secondaryText,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: MyColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.description.isEmpty
                        ? 'No description has been added yet.'
                        : product.description,
                    style: const TextStyle(
                      color: MyColors.secondaryText,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ReviewsSection(product: product),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: MyColors.surfaceCard,
            border: Border(top: BorderSide(color: MyColors.divider)),
          ),
          child: FilledButton.icon(
            onPressed: product.available && (restaurant?.isOpen ?? true)
                ? () => _handleAddToCart(context)
                : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to Cart'),
          ),
        ),
      ),
    );
  }
}

class _CartReplaceSheet extends StatelessWidget {
  const _CartReplaceSheet();

  @override
  Widget build(BuildContext context) {
    return _ActionSheetFrame(
      icon: Icons.shopping_cart_checkout_outlined,
      title: 'Start a new cart?',
      message: 'Orders can include items from one restaurant at a time.',
      primaryLabel: 'Replace cart',
      onPrimary: () => Navigator.pop(context, true),
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.pop(context, false),
    );
  }
}

class _SignInRequiredSheet extends StatelessWidget {
  const _SignInRequiredSheet();

  @override
  Widget build(BuildContext context) {
    return _ActionSheetFrame(
      icon: Icons.login_outlined,
      title: 'Sign in required',
      message: 'You need to be signed in to add items to your cart.',
      primaryLabel: 'Sign in',
      onPrimary: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const SignIn()),
        );
      },
      secondaryLabel: 'Register',
      onSecondary: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const SignUp()),
        );
      },
    );
  }
}

class _ActionSheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  const _ActionSheetFrame({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MyColors.divider),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: MyColors.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: MyColors.goldAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: MyColors.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: MyColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FavouriteAction extends StatelessWidget {
  final String userId;
  final String productId;

  const _FavouriteAction({required this.userId, required this.productId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseService().watchUser(userId),
      builder: (context, snapshot) {
        final favorites = snapshot.data?.favoriteProductIds ?? [];
        final selected = favorites.contains(productId);
        return IconButton(
          tooltip: selected ? 'Remove favourite' : 'Add favourite',
          onPressed: () => FirebaseService().toggleFavorite(
            uid: userId,
            productId: productId,
            isFavorite: selected,
          ),
          icon: Icon(
            selected ? Icons.favorite : Icons.favorite_border,
            color: selected ? MyColors.error : Colors.white,
          ),
        );
      },
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final ProductModel product;

  const _ReviewsSection({required this.product});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<List<ReviewModel>>(
      stream: FirebaseService().getProductReviews(product.id),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];
        final average = reviews.isEmpty
            ? 0.0
            : reviews.fold<int>(0, (sum, item) => sum + item.rating) /
                  reviews.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ratings & Reviews',
                    style: TextStyle(
                      color: MyColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (reviews.isNotEmpty)
                  Text(
                    '${average.toStringAsFixed(1)} / 5',
                    style: const TextStyle(color: MyColors.goldAccent),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (user != null)
              FutureBuilder<bool>(
                future: FirebaseService().hasPurchasedProduct(
                  uid: user.uid,
                  productId: product.id,
                ),
                builder: (context, purchaseSnapshot) {
                  ReviewModel? ownReview;
                  for (final review in reviews) {
                    if (review.customerId == user.uid) {
                      ownReview = review;
                      break;
                    }
                  }
                  final canReview = purchaseSnapshot.data == true;
                  if (ownReview != null) {
                    return const Text(
                      'You have reviewed this item.',
                      style: TextStyle(color: MyColors.secondaryText),
                    );
                  }
                  if (!canReview) {
                    return const Text(
                      'Reviews are available after a delivered order.',
                      style: TextStyle(color: MyColors.secondaryText),
                    );
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _ReviewDialog(product: product),
                      ),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Add review'),
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (reviews.isEmpty)
              const Text(
                'No reviews yet.',
                style: TextStyle(color: MyColors.secondaryText),
              )
            else
              ...reviews
                  .take(5)
                  .map(
                    (review) => _ReviewTile(product: product, review: review),
                  ),
          ],
        );
      },
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  final ProductModel product;
  final ReviewModel? review;

  const _ReviewDialog({required this.product, this.review});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.review?.rating ?? 5;
    _comment.text = widget.review?.comment ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MyColors.surfaceCard,
      title: Text(widget.review == null ? 'Add Review' : 'Edit Review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 1; index <= 5; index++)
                IconButton(
                  onPressed: () => setState(() => _rating = index),
                  icon: Icon(
                    index <= _rating ? Icons.star : Icons.star_border,
                    color: MyColors.ratingStar,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _comment,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Comment'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.review == null ? 'Post' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await FirebaseService().getUser(user.uid);
      if (widget.review == null) {
        await FirebaseService().addReview(
          ReviewModel(
            id: '',
            productId: widget.product.id,
            customerId: user.uid,
            customerName: profile?.name ?? user.email ?? 'Customer',
            rating: _rating,
            comment: _comment.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await FirebaseService().updateReview(
          reviewId: widget.review!.id,
          rating: _rating,
          comment: _comment.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }
}

class _ReviewTile extends StatelessWidget {
  final ProductModel product;
  final ReviewModel review;

  const _ReviewTile({required this.product, required this.review});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isMine = user?.uid == review.customerId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.customerName,
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${review.rating} stars',
                style: const TextStyle(color: MyColors.ratingStar),
              ),
              if (user != null)
                PopupMenuButton<String>(
                  onSelected: (value) => _handleAction(context, value),
                  itemBuilder: (context) => [
                    if (isMine)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isMine)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    if (!isMine)
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Report'),
                      ),
                  ],
                ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: const TextStyle(color: MyColors.secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'edit') {
      await showDialog(
        context: context,
        builder: (_) => _ReviewDialog(product: product, review: review),
      );
      return;
    }

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete review?'),
          content: const Text('Your review will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await FirebaseService().deleteReview(review.id);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (action == 'report' && user != null) {
      await FirebaseService().reportReview(
        reviewId: review.id,
        productId: product.id,
        reporterId: user.uid,
        reason: 'Customer reported this review from the app.',
      );
      if (context.mounted) {
        showAppBottomMessage(
          context,
          title: 'Review reported',
          message: 'Review reported.',
          type: BottomAlertType.success,
        );
      }
    }
  }
}

class _ProductImage extends StatelessWidget {
  final String url;

  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _fallback();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: MyColors.surfaceCard,
      child: const Icon(
        Icons.fastfood,
        size: 100,
        color: MyColors.secondaryText,
      ),
    );
  }
}
