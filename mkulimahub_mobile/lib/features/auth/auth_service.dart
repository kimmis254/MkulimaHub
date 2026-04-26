import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // 🔥 UPDATED: Now returns a Map containing both the Firebase User AND the raw Google Token!
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: '654543955611-g18qameesn4daglsc8pup7rkj6c1n541.apps.googleusercontent.com', 
      );

      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 🔥 THE MAGIC KEY: Grab the raw Google Token before Firebase touches it!
      final String? rawGoogleToken = googleAuth.idToken;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: rawGoogleToken,
      );

      final UserCredential firebaseUser = await _auth.signInWithCredential(credential);
      
      // Return BOTH to the UI
      return {
        'firebase_user': firebaseUser,
        'google_token': rawGoogleToken,
      };
      
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  Future<void> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber, 
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Failed to send OTP. Check the phone number.");
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError("An unexpected error occurred: $e");
    }
  }

  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("OTP Verification Error: $e");
      return null; 
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}