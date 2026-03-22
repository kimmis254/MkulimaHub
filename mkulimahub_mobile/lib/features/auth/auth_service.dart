import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 🔥 v7: It remains a Singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // 🔥 Google Sign-In Logic
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 🔥 v7: Pass the serverClientId directly into the initialize method!
      await _googleSignIn.initialize(
        serverClientId: '654543955611-g18qameesn4daglsc8pup7rkj6c1n541.apps.googleusercontent.com', 
      );

      // 🔥 v7: Use authenticate() instead of signIn()
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();

      // If the user cancels the login, return null
      if (googleUser == null) return null;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 🔥 v7: Firebase only needs the idToken
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the new credential
      return await _auth.signInWithCredential(credential);
      
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
        phoneNumber: phoneNumber, // Must include country code, e.g., +254...
        
        // Android can sometimes automatically read the SMS and log in!
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        
        // If the phone number is invalid or blocked
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Failed to send OTP. Check the phone number.");
        },
        
        // When Firebase successfully sends the SMS, it gives us an ID
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        
        // If it takes too long
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError("An unexpected error occurred: $e");
    }
  }

  // Step B: Verify the code the user typed in
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      // Create a credential using the ID and the 6-digit code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Sign them into Firebase!
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("OTP Verification Error: $e");
      return null; // Code was wrong or expired
    }
  }
  // 🔥 Logout Logic
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}