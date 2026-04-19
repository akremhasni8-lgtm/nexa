import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Statut de l'utilisateur
enum UserStatus {
  authenticated,  // Connecté avec email ou Google
  visitor,        // Mode visiteur (1 scan gratuit)
  unauthenticated // Pas connecté, quota épuisé
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── GETTERS ───────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isAuthenticated => _auth.currentUser != null;

  bool get isVisitor {
    final box = Hive.box('settings');
    return box.get('visitor_mode', defaultValue: false) as bool;
  }

  int get visitorScansUsed {
    final box = Hive.box('settings');
    return box.get('visitor_scans', defaultValue: 0) as int;
  }

  bool get canScanAsVisitor => visitorScansUsed < 1; // 1 scan gratuit

  UserStatus get userStatus {
    if (isAuthenticated) return UserStatus.authenticated;
    if (isVisitor && canScanAsVisitor) return UserStatus.visitor;
    return UserStatus.unauthenticated;
  }

  // ── EMAIL / MOT DE PASSE ──────────────────────────────────

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _clearVisitorMode();
    return cred;
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null) {
      await cred.user?.updateDisplayName(displayName);
    }
    await cred.user?.sendEmailVerification();
    _clearVisitorMode();
    return cred;
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── GOOGLE SIGN IN ────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // Annulé

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    _clearVisitorMode();
    return cred;
  }

  // ── MODE VISITEUR ─────────────────────────────────────────

  Future<void> continueAsVisitor() async {
    final box = Hive.box('settings');
    await box.put('visitor_mode', true);
    await box.put('visitor_scans', 0);
  }

  Future<void> incrementVisitorScan() async {
    final box = Hive.box('settings');
    final current = box.get('visitor_scans', defaultValue: 0) as int;
    await box.put('visitor_scans', current + 1);
  }

  void _clearVisitorMode() {
    final box = Hive.box('settings');
    box.put('visitor_mode', false);
    box.put('visitor_scans', 0);
  }

  // ── DÉCONNEXION ───────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── HELPER : message d'erreur Firebase ───────────────────

  static String errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères min).';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Vérifiez votre connexion internet.';
      default:
        return 'Une erreur est survenue. Réessayez.';
    }
  }
}