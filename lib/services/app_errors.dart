import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../state/session_expired.dart';
import '../theme.dart';
import 'api_service.dart';

/// Metadata describing a known application error code.
class FTErrorInfo {
  final String code;
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const FTErrorInfo({
    required this.code,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

/// Central catalog of all error codes the backend can return.
const Map<String, FTErrorInfo> _catalog = {
  // ---- Auth ----
  'AUTH_001': FTErrorInfo(
    code: 'AUTH_001',
    title: 'Invalid Credentials',
    message: 'The email or password you entered is incorrect. Please try again.',
    icon: Icons.lock_rounded,
    color: FT.danger,
  ),
  'AUTH_002': FTErrorInfo(
    code: 'AUTH_002',
    title: 'Session Expired',
    message: 'Your session has expired. Please log in again to continue.',
    icon: Icons.timer_off_rounded,
    color: FT.goldDark,
  ),
  'AUTH_003': FTErrorInfo(
    code: 'AUTH_003',
    title: 'Unauthorized Access',
    message: 'You do not have permission to perform this action.',
    icon: Icons.shield_rounded,
    color: FT.danger,
  ),

  // ---- User ----
  'USER_001': FTErrorInfo(
    code: 'USER_001',
    title: 'User Not Found',
    message: 'We could not find this account. Please check and try again.',
    icon: Icons.person_off_rounded,
    color: FT.goldDark,
  ),
  'USER_002': FTErrorInfo(
    code: 'USER_002',
    title: 'User Already Exists',
    message: 'An account with these details already exists.',
    icon: Icons.person_add_alt_1_rounded,
    color: FT.goldDark,
  ),
  'USER_003': FTErrorInfo(
    code: 'USER_003',
    title: 'Invalid User Data',
    message: 'Some of the details you entered are not valid. Please review them.',
    icon: Icons.manage_accounts_rounded,
    color: FT.danger,
  ),

  // ---- Trip / Order ----
  'TRIP_001': FTErrorInfo(
    code: 'TRIP_001',
    title: 'Trip Not Found',
    message: 'This delivery trip could not be found. It may have been removed.',
    icon: Icons.near_me_disabled_rounded,
    color: FT.goldDark,
  ),
  'TRIP_002': FTErrorInfo(
    code: 'TRIP_002',
    title: 'Trip Already Accepted',
    message: 'Another rider already accepted this trip. Check available deliveries for new ones.',
    icon: Icons.assignment_turned_in_rounded,
    color: FT.goldDark,
  ),
  'TRIP_003': FTErrorInfo(
    code: 'TRIP_003',
    title: 'Driver Unavailable',
    message: 'You are currently unavailable to take this trip.',
    icon: Icons.person_off_rounded,
    color: FT.goldDark,
  ),
  'TRIP_004': FTErrorInfo(
    code: 'TRIP_004',
    title: 'Trip Cancelled',
    message: 'This trip was cancelled by the customer or the shop.',
    icon: Icons.event_busy_rounded,
    color: FT.goldDark,
  ),

  // ---- Payment ----
  'PAY_001': FTErrorInfo(
    code: 'PAY_001',
    title: 'Payment Failed',
    message: 'The payment could not be processed. Please try again.',
    icon: Icons.payment_rounded,
    color: FT.danger,
  ),
  'PAY_002': FTErrorInfo(
    code: 'PAY_002',
    title: 'Insufficient Balance',
    message: 'There is not enough balance to complete this transaction.',
    icon: Icons.account_balance_wallet_rounded,
    color: FT.danger,
  ),
  'PAY_003': FTErrorInfo(
    code: 'PAY_003',
    title: 'Payment Timeout',
    message: 'The payment request timed out. Please check your connection and retry.',
    icon: Icons.schedule_rounded,
    color: FT.goldDark,
  ),
  'PAY_004': FTErrorInfo(
    code: 'PAY_004',
    title: 'Transaction Already Processed',
    message: 'This transaction has already been completed.',
    icon: Icons.done_all_rounded,
    color: FT.green700,
  ),

  // ---- GPS ----
  'GPS_001': FTErrorInfo(
    code: 'GPS_001',
    title: 'Location Permission Denied',
    message: 'Location permission is required. Please enable it in your device settings.',
    icon: Icons.location_off_rounded,
    color: FT.danger,
  ),
  'GPS_002': FTErrorInfo(
    code: 'GPS_002',
    title: 'Location Unavailable',
    message: 'Your current location could not be determined. Make sure location services are on.',
    icon: Icons.location_disabled_rounded,
    color: FT.goldDark,
  ),
  'GPS_003': FTErrorInfo(
    code: 'GPS_003',
    title: 'Weak GPS Signal',
    message: 'The GPS signal is weak. Move to an open area for a better signal.',
    icon: Icons.gps_off_rounded,
    color: FT.goldDark,
  ),

  // ---- Network ----
  'NET_001': FTErrorInfo(
    code: 'NET_001',
    title: 'No Internet Connection',
    message: 'Please check your internet connection and try again.',
    icon: Icons.wifi_off_rounded,
    color: FT.danger,
  ),
  'NET_002': FTErrorInfo(
    code: 'NET_002',
    title: 'Request Timeout',
    message: 'The request took too long to complete. Please try again.',
    icon: Icons.hourglass_empty_rounded,
    color: FT.goldDark,
  ),
  'NET_003': FTErrorInfo(
    code: 'NET_003',
    title: 'Server Unavailable',
    message: 'The server is currently unreachable. Please try again shortly.',
    icon: Icons.cloud_off_rounded,
    color: FT.danger,
  ),

  // ---- General ----
  'APP_001': FTErrorInfo(
    code: 'APP_001',
    title: 'Unexpected Error',
    message: 'Something went wrong. Please try again.',
    icon: Icons.error_outline_rounded,
    color: FT.danger,
  ),
  'APP_002': FTErrorInfo(
    code: 'APP_002',
    title: 'Invalid Request',
    message: 'The request could not be completed as it was not valid.',
    icon: Icons.info_rounded,
    color: FT.goldDark,
  ),
  'APP_003': FTErrorInfo(
    code: 'APP_003',
    title: 'Service Temporarily Unavailable',
    message: 'Our service is temporarily down for maintenance. Please try again later.',
    icon: Icons.construction_rounded,
    color: FT.goldDark,
  ),
};

final RegExp _codePattern = RegExp(r'[A-Z]{3,4}_\d{3}');

/// Extracts a known error code (e.g. "TRIP_002") from any thrown error.
String? extractErrorCode(Object? error) {
  if (error == null) return null;
  if (error is AuthExpiredException) return 'AUTH_002';
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final c = data['code'];
      if (c is String && c.trim().isNotEmpty) return c.trim();
      final e = data['error'];
      if (e is String) {
        final m = _codePattern.firstMatch(e);
        if (m != null) return m.group(0);
      }
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'NET_002';
    }
    if (error.type == DioExceptionType.connectionError) return 'NET_001';
  }
  final msg = error.toString();
  final m = _codePattern.firstMatch(msg);
  if (m != null) return m.group(0);
  return null;
}

/// Resolves any thrown error into rich popup metadata, or null when the
/// error is not a known code (callers should fall back to a snackbar).
FTErrorInfo? resolveErrorInfo(Object? error) {
  final code = extractErrorCode(error);
  if (code != null) {
    final info = _catalog[code];
    if (info != null) return info;
  }
  final msg = error.toString().toLowerCase();
  for (final info in _catalog.values) {
    if (msg.contains(info.message.toLowerCase()) ||
        msg.contains(info.title.toLowerCase())) {
      return info;
    }
  }
  return null;
}

/// SweetAlert-style frosted-glass popup for known error codes.
Future<void> showFTErrorPopup(
  BuildContext context, {
  required String title,
  required String message,
  required String code,
  required IconData icon,
  required Color color,
  String? confirmLabel,
  VoidCallback? onConfirm,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: glassCardDecoration(radius: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.45), width: 1.6),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: color),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FT.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: FT.inkSoft, height: 1.45),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: ftGlassFilledStyle(color),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onConfirm?.call();
                    },
                    child: Text(confirmLabel ?? 'OK', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shows a popup for all errors (known and unknown).
/// Uses the app's root navigator so it survives widget rebuilds/unmounts.
void showFTError(BuildContext context, Object? error) {
  final navCtx = ApiSessionExpiredBinder.navigatorKey.currentContext;
  final info = resolveErrorInfo(error);
  final target = navCtx ?? (context.mounted ? context : null);
  if (target == null) return;
  
  final displayInfo = info ?? FTErrorInfo(
    code: 'APP_001',
    title: 'Error',
    message: ApiService.errorMessage(error),
    icon: Icons.error_outline_rounded,
    color: FT.danger,
  );
  
  showFTErrorPopup(
    target,
    title: displayInfo.title,
    message: displayInfo.message,
    code: displayInfo.code,
    icon: displayInfo.icon,
    color: displayInfo.color,
  );
}
