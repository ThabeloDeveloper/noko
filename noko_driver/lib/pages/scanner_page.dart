import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:noko_driver/constants/colors.dart';
import 'package:noko_driver/data/services/firebase_service.dart';

class ScannerPage extends StatefulWidget {
  final String? orderId;

  const ScannerPage({super.key, this.orderId});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Order QR"),
        backgroundColor: MyColors.primary,
      ),
      body: MobileScanner(
        onDetect: (capture) async {
          if (!isScanning) return;

          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            final String? code = barcode.rawValue;
            if (code != null) {
              setState(() => isScanning = false);
              try {
                final driverId = FirebaseAuth.instance.currentUser?.uid;
                if (driverId == null) {
                  throw Exception('Driver is not signed in.');
                }
                await FirebaseService().settleOrder(
                  qrPayload: code,
                  driverId: driverId,
                  expectedOrderId: widget.orderId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Order delivered successfully!"),
                      backgroundColor: MyColors.success,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: ${e.toString()}"),
                      backgroundColor: MyColors.error,
                    ),
                  );
                  setState(() => isScanning = true);
                }
              }
              break;
            }
          }
        },
      ),
    );
  }
}
