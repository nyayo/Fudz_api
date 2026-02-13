import 'package:food_delivery_customer_app/services/error_logger_service.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService extends GetxService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '420175212968-lqga32ger8fcfrve7jp99259ljrd0elm.apps.googleusercontent.com',
  );
  
  ErrorLoggerService? _errorLogger;
  
  @override
  void onInit() {
    super.onInit();
    // Get error logger if available
    if (Get.isRegistered<ErrorLoggerService>()) {
      _errorLogger = Get.find<ErrorLoggerService>();
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _errorLogger?.logAuthInfo('Starting Google Sign-in flow');
      
      final account = await _googleSignIn.signIn();
      
      if (account != null) {
        _errorLogger?.logAuthInfo(
          'Google Sign-in successful',
          metadata: {
            'email': account.email,
            'display_name': account.displayName,
          },
        );
      } else {
        _errorLogger?.logAuthWarning('Google Sign-in cancelled by user');
      }
      
      return account;
    } catch (e, stackTrace) {
      _errorLogger?.logGoogleSignInError(
        message: 'Google Sign-in failed',
        error: e,
        stackTrace: stackTrace,
      );
      print('Google Sign-In error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }
}
