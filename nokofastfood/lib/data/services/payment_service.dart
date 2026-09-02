enum PaymentMethod { cashOnDelivery, peachPayments }

class PaymentResult {
  final bool success;
  final String paymentMethod;
  final String paymentStatus;

  const PaymentResult({
    required this.success,
    required this.paymentMethod,
    required this.paymentStatus,
  });
}

class PaymentService {
  Future<PaymentResult> processPayment({
    required double amount,
    required PaymentMethod method,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Order total must be greater than zero.');
    }

    switch (method) {
      case PaymentMethod.cashOnDelivery:
        return const PaymentResult(
          success: true,
          paymentMethod: 'cash_on_delivery',
          paymentStatus: 'pending',
        );
      case PaymentMethod.peachPayments:
        return const PaymentResult(
          success: true,
          paymentMethod: 'peach_payments',
          paymentStatus: 'pending',
        );
    }
  }
}
