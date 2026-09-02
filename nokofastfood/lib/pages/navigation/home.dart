import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nokofastfood/constants/bottom_alert.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nokofastfood/data/models/menu_category_model.dart';
import 'package:nokofastfood/data/models/product_model.dart';
import 'package:nokofastfood/data/models/promo_code_model.dart';
import 'package:nokofastfood/data/models/restaurant_model.dart';
import 'package:nokofastfood/data/providers/cart_provider.dart';
import 'package:nokofastfood/data/services/firebase_service.dart';
import 'package:nokofastfood/pages/cart_page.dart';
import 'package:nokofastfood/pages/auth/sign_in.dart';
import 'package:nokofastfood/pages/auth/sign_up.dart';
import 'package:nokofastfood/pages/product_detail.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/colors.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final FirebaseService _service = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  final PageController _featuredController = PageController(
    viewportFraction: 0.9,
  );
  String? _selectedRestaurantId;
  String _selectedCategory = 'All';
  bool _showAvailableOnly = true;

  @override
  void dispose() {
    _searchController.dispose();
    _featuredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Noko Fast Food',
              style: GoogleFonts.poppins(
                color: MyColors.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Choose a restaurant, then build your order',
              style: GoogleFonts.poppins(
                color: MyColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: 'Cart',
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const CartPage()),
                  );
                },
                icon: const Icon(
                  Icons.shopping_basket_outlined,
                  color: MyColors.primaryText,
                ),
              ),
              if (cart.totalQuantity > 0)
                Positioned(
                  right: 10,
                  top: 6,
                  child: Badge(
                    label: Text(cart.totalQuantity.toString()),
                    backgroundColor: MyColors.goldAccent,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<RestaurantModel>>(
        stream: _service.getRestaurants(),
        builder: (context, restaurantSnapshot) {
          if (restaurantSnapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline,
              title: 'Restaurants could not load',
              subtitle: '${restaurantSnapshot.error}',
            );
          }
          if (!restaurantSnapshot.hasData) {
            return _buildShimmerList();
          }

          final restaurants = restaurantSnapshot.data ?? [];
          if (restaurants.isEmpty) {
            return const _StateMessage(
              icon: Icons.storefront_outlined,
              title: 'No restaurants available',
            );
          }

          final selectedRestaurant = restaurants.firstWhere(
            (restaurant) => restaurant.id == _selectedRestaurantId,
            orElse: () => restaurants.first,
          );
          _selectedRestaurantId ??= selectedRestaurant.id;

          return StreamBuilder<List<ProductModel>>(
            stream: _service.getProducts(selectedRestaurant.id),
            builder: (context, productSnapshot) {
              if (productSnapshot.hasError) {
                return _StateMessage(
                  icon: Icons.error_outline,
                  title: 'Menu could not load',
                  subtitle: '${productSnapshot.error}',
                );
              }
              if (!productSnapshot.hasData) {
                return _buildShimmerGrid();
              }

              return StreamBuilder(
                stream: _service.getMenuCategories(),
                builder: (context, categorySnapshot) {
                  final products = productSnapshot.data ?? [];
                  final menuCategories =
                      (categorySnapshot.data ?? <MenuCategoryModel>[]);
                  final orderedNames = menuCategories
                      .map((item) => item.name.trim())
                      .where((name) => name.isNotEmpty)
                      .toList();
                  final productNames =
                      products
                          .map((item) => item.category.trim())
                          .where(
                            (name) =>
                                name.isNotEmpty && !orderedNames.contains(name),
                          )
                          .toSet()
                          .toList()
                        ..sort();
                  final categories = [
                    'All',
                    ...orderedNames.where(
                      (name) => products.any(
                        (product) => product.category.trim() == name,
                      ),
                    ),
                    ...productNames,
                  ];
                  if (!categories.contains(_selectedCategory)) {
                    _selectedCategory = 'All';
                  }
                  final query = _searchController.text.toLowerCase();
                  final filteredProducts = products.where((product) {
                    final matchesSearch = [
                      product.name,
                      product.description,
                      product.category,
                    ].any((value) => value.toLowerCase().contains(query));
                    final matchesCategory =
                        _selectedCategory == 'All' ||
                        product.category == _selectedCategory;
                    final matchesAvailability =
                        !_showAvailableOnly || product.available;
                    return matchesSearch &&
                        matchesCategory &&
                        matchesAvailability;
                  }).toList();
                  final featuredProducts = _featuredProducts(
                    restaurantId: selectedRestaurant.id,
                    products: products,
                    categories: menuCategories,
                  );

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _MzansiHero(
                          key: ValueKey(selectedRestaurant.id),
                          restaurant: selectedRestaurant,
                          products: featuredProducts,
                          controller: _featuredController,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _RestaurantSelector(
                          restaurants: restaurants,
                          selectedRestaurantId: selectedRestaurant.id,
                          onSelected: (restaurant) {
                            setState(() {
                              _selectedRestaurantId = restaurant.id;
                              _selectedCategory = 'All';
                            });
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _PromoDiscovery(service: _service),
                      ),
                      SliverToBoxAdapter(
                        child: _MenuFilters(
                          searchController: _searchController,
                          categories: categories,
                          selectedCategory: _selectedCategory,
                          showAvailableOnly: _showAvailableOnly,
                          onSearch: (_) => setState(() {}),
                          onCategorySelected: (category) =>
                              setState(() => _selectedCategory = category),
                          onAvailabilityChanged: (value) =>
                              setState(() => _showAvailableOnly = value),
                        ),
                      ),
                      if (!selectedRestaurant.isOpen)
                        const SliverToBoxAdapter(
                          child: _NoticeCard(
                            icon: Icons.lock_clock_outlined,
                            text: 'This restaurant is closed right now.',
                          ),
                        ),
                      if (filteredProducts.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _StateMessage(
                            icon: Icons.restaurant_menu,
                            title: 'No menu items found',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(12),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 250,
                                  childAspectRatio: 0.74,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _ProductTile(
                                product: product,
                                restaurant: selectedRestaurant,
                                enabled:
                                    product.available &&
                                    selectedRestaurant.isOpen,
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: MyColors.surfaceCard,
      highlightColor: MyColors.divider,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, _) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: MyColors.surfaceCard,
      highlightColor: MyColors.divider,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: 0.74,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  List<ProductModel> _featuredProducts({
    required String restaurantId,
    required List<ProductModel> products,
    required List<MenuCategoryModel> categories,
  }) {
    final availableProducts = products
        .where((product) => product.available)
        .toList();
    if (availableProducts.isEmpty) {
      return products.take(5).toList();
    }

    final orderedCategoryNames = categories
        .map((category) => category.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final firstCategory = orderedCategoryNames.firstWhere(
      (name) => availableProducts.any((product) => product.category == name),
      orElse: () => availableProducts.first.category,
    );
    final featured = <ProductModel>[
      ...availableProducts
          .where((product) => product.category == firstCategory)
          .take(3),
    ];

    final remainingCategories = availableProducts
        .where((product) => product.category != firstCategory)
        .map((product) => product.category)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    remainingCategories.shuffle(Random(restaurantId.hashCode));
    for (final category in remainingCategories.take(2)) {
      final categoryItems = availableProducts
          .where(
            (product) =>
                product.category == category &&
                !featured.any((item) => item.id == product.id),
          )
          .toList();
      categoryItems.shuffle(Random(category.hashCode ^ restaurantId.hashCode));
      if (categoryItems.isNotEmpty) {
        featured.add(categoryItems.first);
      }
    }

    for (final product in availableProducts) {
      if (featured.length >= 5) break;
      if (!featured.any((item) => item.id == product.id)) {
        featured.add(product);
      }
    }

    return featured.take(5).toList();
  }
}

class _MzansiHero extends StatefulWidget {
  final RestaurantModel restaurant;
  final List<ProductModel> products;
  final PageController controller;

  const _MzansiHero({
    super.key,
    required this.restaurant,
    required this.products,
    required this.controller,
  });

  @override
  State<_MzansiHero> createState() => _MzansiHeroState();
}

class _MzansiHeroState extends State<_MzansiHero> {
  int _page = 0;

  @override
  void didUpdateWidget(covariant _MzansiHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.products.length && widget.products.isNotEmpty) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.hasClients) {
          widget.controller.jumpToPage(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 720;
    final heroHeight = isWide ? 360.0 : 430.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      height: heroHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF170B0D),
        border: Border.all(color: const Color(0xFF4C1A1F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2B0F13),
                    MyColors.primaryDark,
                    const Color(0xFF111111),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -26,
            top: -18,
            child: _PatternRing(size: 116, color: MyColors.goldAccent),
          ),
          Positioned(
            right: -42,
            bottom: -46,
            child: _PatternRing(size: 180, color: const Color(0xFF1BA160)),
          ),
          Padding(
            padding: EdgeInsets.all(isWide ? 24 : 18),
            child: isWide
                ? Row(
                    children: [
                      Expanded(child: _HeroCopy(restaurant: widget.restaurant)),
                      const SizedBox(width: 22),
                      SizedBox(
                        width: 430,
                        child: _FeaturedPager(
                          restaurant: widget.restaurant,
                          products: widget.products,
                          controller: widget.controller,
                          page: _page,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroCopy(restaurant: widget.restaurant),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _FeaturedPager(
                          restaurant: widget.restaurant,
                          products: widget.products,
                          controller: widget.controller,
                          page: _page,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final RestaurantModel restaurant;

  const _HeroCopy({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: MyColors.goldAccent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text(
            'Mzansi flavour drop',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Hot, cheesy, saucy goodness.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: MyColors.primaryText,
            fontSize: 32,
            height: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Fresh picks from ${restaurant.name}. Big-share energy, local comfort, and quick bites made for right now.',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: MyColors.secondaryText,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _HeroPill(icon: Icons.local_fire_department, label: 'Hot deals'),
            _HeroPill(icon: Icons.groups_2_outlined, label: 'Share meals'),
            _HeroPill(icon: Icons.delivery_dining, label: 'Fast delivery'),
          ],
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: MyColors.goldAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: MyColors.primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedPager extends StatelessWidget {
  final RestaurantModel restaurant;
  final List<ProductModel> products;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;

  const _FeaturedPager({
    required this.restaurant,
    required this.products,
    required this.controller,
    required this.page,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _FeatureEmpty();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: products.length,
                onPageChanged: onPageChanged,
                padEnds: false,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _FeaturedItem(
                      product: products[index],
                      restaurant: restaurant,
                    ),
                  );
                },
              ),
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: _PagerButton(
                  icon: Icons.chevron_left,
                  onPressed: page == 0
                      ? null
                      : () => controller.previousPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ),
                ),
              ),
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: _PagerButton(
                  icon: Icons.chevron_right,
                  onPressed: page >= products.length - 1
                      ? null
                      : () => controller.nextPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < products.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: page == index ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: page == index
                      ? MyColors.goldAccent
                      : Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedItem extends StatelessWidget {
  final ProductModel product;
  final RestaurantModel restaurant;

  const _FeaturedItem({required this.product, required this.restaurant});

  Future<void> _addToCart(BuildContext context) async {
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
        builder: (context) => const _HomeCartReplaceSheet(),
      );
      if (replace != true || !context.mounted) {
        return;
      }
      cart.clear();
    }

    cart.addItem(product);
    if (!context.mounted) return;
    showAppBottomMessage(
      context,
      title: 'Added to cart',
      message: '${product.name} added to cart.',
      type: BottomAlertType.success,
    );
  }

  void _showSignInRequired(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HomeSignInRequiredSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = product.available && restaurant.isOpen;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ProductDetailPage(
              product: product,
              restaurant: restaurant,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NetworkImage(
              url: product.imageUrl,
              icon: Icons.local_pizza_outlined,
              width: double.infinity,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MyColors.goldAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: MyColors.primaryText,
                      fontSize: 20,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'R${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: MyColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: enabled ? 'Add to cart' : 'Unavailable',
                        child: IconButton.filled(
                          onPressed: enabled ? () => _addToCart(context) : null,
                          style: IconButton.styleFrom(
                            backgroundColor: MyColors.primary,
                            disabledBackgroundColor:
                                MyColors.buttonDisabled,
                            foregroundColor: MyColors.primaryText,
                            minimumSize: const Size(42, 42),
                          ),
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _PagerButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton.filled(
        tooltip: icon == Icons.chevron_left ? 'Previous' : 'Next',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.55),
          disabledBackgroundColor: Colors.black.withValues(alpha: 0.18),
          foregroundColor: MyColors.primaryText,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _FeatureEmpty extends StatelessWidget {
  const _FeatureEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Text(
        'Featured menu picks will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: MyColors.secondaryText),
      ),
    );
  }
}

class _PatternRing extends StatelessWidget {
  final double size;
  final Color color;

  const _PatternRing({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.24), width: 18),
      ),
    );
  }
}

class _PromoDiscovery extends StatelessWidget {
  final FirebaseService service;

  const _PromoDiscovery({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoCodeModel>>(
      stream: service.getActivePromoCodes(),
      builder: (context, snapshot) {
        final promos = snapshot.data ?? [];
        if (promos.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 86,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            scrollDirection: Axis.horizontal,
            itemCount: promos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final promo = promos[index];
              return _PromoCard(promo: promo);
            },
          ),
        );
      },
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromoCodeModel promo;

  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final value = promo.type == 'percent'
        ? '${promo.value.toStringAsFixed(0)}% off'
        : 'R${promo.value.toStringAsFixed(0)} off';
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyColors.goldAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MyColors.goldAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: MyColors.goldAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  promo.code,
                  style: const TextStyle(
                    color: MyColors.primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$value from R${promo.minSubtotal.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MyColors.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantSelector extends StatelessWidget {
  final List<RestaurantModel> restaurants;
  final String selectedRestaurantId;
  final ValueChanged<RestaurantModel> onSelected;

  const _RestaurantSelector({
    required this.restaurants,
    required this.selectedRestaurantId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.horizontal,
        itemCount: restaurants.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          final selected = restaurant.id == selectedRestaurantId;
          return InkWell(
            onTap: () => onSelected(restaurant),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 260,
              decoration: BoxDecoration(
                color: MyColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? MyColors.goldAccent : MyColors.divider,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: _NetworkImage(
                        url: restaurant.imageUrl,
                        icon: Icons.storefront_outlined,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MyColors.primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _StatusDot(open: restaurant.isOpen),
                      ],
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
}

class _MenuFilters extends StatelessWidget {
  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final bool showAvailableOnly;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<bool> onAvailabilityChanged;

  const _MenuFilters({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.showAvailableOnly,
    required this.onSearch,
    required this.onCategorySelected,
    required this.onAvailabilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearch,
            style: const TextStyle(color: MyColors.primaryText),
            decoration: InputDecoration(
              hintText: 'Search food, drinks, categories',
              hintStyle: const TextStyle(color: MyColors.secondaryText),
              prefixIcon: const Icon(Icons.search, color: MyColors.goldAccent),
              filled: true,
              fillColor: MyColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return ChoiceChip(
                        label: Text(category),
                        selected: category == selectedCategory,
                        onSelected: (_) => onCategorySelected(category),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Available'),
                selected: showAvailableOnly,
                onSelected: onAvailabilityChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final RestaurantModel restaurant;
  final bool enabled;

  const _ProductTile({
    required this.product,
    required this.restaurant,
    required this.enabled,
  });

  Future<void> _addToCart(BuildContext context) async {
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
        builder: (context) => const _HomeCartReplaceSheet(),
      );
      if (replace != true || !context.mounted) {
        return;
      }
      cart.clear();
    }

    cart.addItem(product);
    if (!context.mounted) return;
    showAppBottomMessage(
      context,
      title: 'Added to cart',
      message: '${product.name} added to cart.',
      type: BottomAlertType.success,
    );
  }

  void _showSignInRequired(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HomeSignInRequiredSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return InkWell(
      onTap: enabled
          ? () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => ProductDetailPage(
                    product: product,
                    restaurant: restaurant,
                  ),
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: MyColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MyColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: _NetworkImage(
                        url: product.imageUrl,
                        icon: Icons.fastfood,
                        width: double.infinity,
                      ),
                    ),
                    if (user != null)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _FavouriteButton(productId: product.id),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: MyColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MyColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'R${product.price.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MyColors.goldAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: enabled ? 'Add to cart' : 'Unavailable',
                          child: IconButton.filled(
                            onPressed: enabled ? () => _addToCart(context) : null,
                            style: IconButton.styleFrom(
                              backgroundColor: MyColors.primary,
                              disabledBackgroundColor: MyColors.buttonDisabled,
                              foregroundColor: MyColors.primaryText,
                              minimumSize: const Size(40, 40),
                            ),
                            icon: const Icon(Icons.add_shopping_cart, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCartReplaceSheet extends StatelessWidget {
  const _HomeCartReplaceSheet();

  @override
  Widget build(BuildContext context) {
    return _HomeActionSheetFrame(
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

class _HomeSignInRequiredSheet extends StatelessWidget {
  const _HomeSignInRequiredSheet();

  @override
  Widget build(BuildContext context) {
    return _HomeActionSheetFrame(
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

class _HomeActionSheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  const _HomeActionSheetFrame({
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

class _FavouriteButton extends StatelessWidget {
  final String productId;

  const _FavouriteButton({required this.productId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder(
      stream: FirebaseService().watchUser(user.uid),
      builder: (context, snapshot) {
        final favorites = snapshot.data?.favoriteProductIds ?? [];
        final selected = favorites.contains(productId);
        return Material(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          child: IconButton(
            tooltip: selected ? 'Remove favourite' : 'Add favourite',
            onPressed: () => FirebaseService().toggleFavorite(
              uid: user.uid,
              productId: productId,
              isFavorite: selected,
            ),
            icon: Icon(
              selected ? Icons.favorite : Icons.favorite_border,
              color: selected ? MyColors.error : MyColors.primaryText,
            ),
          ),
        );
      },
    );
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  final IconData icon;
  final double? width;

  const _NetworkImage({required this.url, required this.icon, this.width});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _imageFallback(icon);
    }
    return Image.network(
      url,
      width: width,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _imageFallback(icon),
    );
  }
}

Widget _imageFallback(IconData icon) {
  return Container(
    width: double.infinity,
    height: double.infinity,
    color: MyColors.elevatedSurface,
    child: Icon(icon, color: MyColors.secondaryText, size: 48),
  );
}

class _StatusDot extends StatelessWidget {
  final bool open;

  const _StatusDot({required this.open});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          color: open ? MyColors.success : MyColors.error,
          size: 10,
        ),
        const SizedBox(width: 4),
        Text(
          open ? 'Open' : 'Closed',
          style: TextStyle(
            color: open ? MyColors.success : MyColors.error,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoticeCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MyColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: MyColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: MyColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _StateMessage({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: MyColors.goldAccent, size: 58),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MyColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: MyColors.secondaryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
