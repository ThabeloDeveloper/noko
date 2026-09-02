import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;

import '../constants/bottom_alert.dart';
import '../constants/colors.dart';

class PeachCheckoutPage extends StatefulWidget {
  final String checkoutUrl;

  const PeachCheckoutPage({super.key, required this.checkoutUrl});

  @override
  State<PeachCheckoutPage> createState() => _PeachCheckoutPageState();
}

class _PeachCheckoutPageState extends State<PeachCheckoutPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialiseWebView();
  }

  Future<void> _initialiseWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri?.scheme == 'noko' && uri?.host == 'peach-payment') {
              Navigator.of(context).pop(uri?.pathSegments.first == 'completed');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            showAppBottomMessage(
              context,
              title: 'Payment page error',
              message: error.description,
              type: BottomAlertType.error,
            );
          },
        ),
      );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _controller.enableZoom(false);
      final androidController =
          _controller.platform
              as webview_flutter_android.AndroidWebViewController;
      final paymentRequestEnabled = await androidController
          .isWebViewFeatureSupported(
            webview_flutter_android.WebViewFeatureType.paymentRequest,
          );
      if (paymentRequestEnabled) {
        await androidController.setPaymentRequestEnabled(true);
        await androidController.setMediaPlaybackRequiresUserGesture(false);
      }
    }

    await _controller.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.background,
      appBar: AppBar(
        title: const Text(
          'Peach Payments',
          style: TextStyle(color: MyColors.primaryText),
        ),
        backgroundColor: MyColors.background,
        iconTheme: const IconThemeData(color: MyColors.primaryText),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: MyColors.primary),
            ),
        ],
      ),
    );
  }
}
