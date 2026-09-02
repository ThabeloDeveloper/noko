import 'package:flutter/material.dart';

import 'colors.dart';

enum BottomAlertType { success, error, warning, info }

Future<void> showAppBottomMessage(
  BuildContext context, {
  required String title,
  required String message,
  BottomAlertType type = BottomAlertType.info,
  String actionLabel = 'OK',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BottomAlert(
      title: title,
      message: message,
      type: type,
      actionLabel: actionLabel,
    ),
  );
}

class BottomAlert extends StatelessWidget {
  final String title;
  final String message;
  final BottomAlertType type;
  final String actionLabel;

  const BottomAlert({
    super.key,
    required this.title,
    required this.message,
    this.type = BottomAlertType.info,
    this.actionLabel = 'OK',
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(type);
    final icon = _iconFor(type);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final displayMessage = _friendlyMessage(message);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: MyColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: MyColors.primaryText,
                                  fontSize: 18,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                displayMessage,
                                style: const TextStyle(
                                  color: MyColors.secondaryText,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: () => Navigator.pop(context),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFor(BottomAlertType type) {
    switch (type) {
      case BottomAlertType.success:
        return MyColors.success;
      case BottomAlertType.error:
        return MyColors.error;
      case BottomAlertType.warning:
        return MyColors.warning;
      case BottomAlertType.info:
        return MyColors.goldAccent;
    }
  }

  IconData _iconFor(BottomAlertType type) {
    switch (type) {
      case BottomAlertType.success:
        return Icons.check_circle_outline;
      case BottomAlertType.error:
        return Icons.error_outline;
      case BottomAlertType.warning:
        return Icons.warning_amber_outlined;
      case BottomAlertType.info:
        return Icons.info_outline;
    }
  }

  String _friendlyMessage(String value) {
    final raw = value.trim();
    final lower = raw.toLowerCase();

    if (lower.contains('googlesigninexception') ||
        lower.contains('google sign in') ||
        lower.contains('requestedscopes')) {
      if (lower.contains('cancel')) {
        return 'Google sign in was cancelled.';
      }
      if (lower.contains('network')) {
        return 'Please check your internet connection and try Google sign in again.';
      }
      if (lower.contains('requestedscopes')) {
        return 'Google sign in could not start. Please update the app and try again.';
      }
      return 'Google sign in could not be completed. Please try again.';
    }

    if (lower.contains('invalid-phone-number')) {
      return 'Enter a valid phone number, including the country code.';
    }
    if (lower.contains('invalid-verification-code') ||
        lower.contains('invalid-verification-id')) {
      return 'That verification code is not correct. Please check it and try again.';
    }
    if (lower.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('quota-exceeded')) {
      return 'SMS quota has been reached for now. Please try again later.';
    }
    if (lower.contains('operation-not-allowed') &&
        (lower.contains('phone') || lower.contains('firebase_auth'))) {
      return 'Phone sign-in is not enabled in Firebase yet.';
    }

    if (lower.contains('firebase_functions/internal') ||
        lower.contains('cloudfunctionshostapi.call') ||
        lower.contains('stacktrace:') ||
        lower.contains('\nat ') ||
        lower.contains('\n#0')) {
      return 'Something went wrong. Please try again.';
    }

    final withoutException = raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('[firebase_auth/', '')
        .replaceAll(']', '')
        .trim();

    final messageOnly = withoutException.contains('message:')
        ? withoutException.split('message:').last.trim()
        : withoutException;

    return messageOnly.isEmpty
        ? 'Something went wrong. Please try again.'
        : messageOnly;
  }
}
