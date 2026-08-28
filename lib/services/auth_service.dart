import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// centraliza tudo que mexe com login/cadastro/sessao, pra nao ficar duplicado pelas telas
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleSignInPronto = false;

  User? get usuarioAtual => _auth.currentUser;
  Stream<User?> get mudancasDeEstado => _auth.authStateChanges();

  Future<void> _garantirGoogleSignInInicializado() async {
    if (_googleSignInPronto) return;
    await GoogleSignIn.instance.initialize(
      // "Web client ID" gerado pelo Firebase Console quando voce habilita o provedor Google
      // (Authentication > Sign-in method > Google > Web SDK configuration)
      serverClientId: '890336956924-lnokgj8k18f9abqk1g9sms5jujbkg6lu.apps.googleusercontent.com.apps.googleusercontent.com',
    );
    _googleSignInPronto = true;
  }

  Future<UserCredential> entrarComEmailSenha(String email, String senha) {
    return _auth.signInWithEmailAndPassword(email: email, password: senha);
  }

  Future<UserCredential> cadastrarComEmailSenha(String email, String senha) {
    return _auth.createUserWithEmailAndPassword(email: email, password: senha);
  }

  // retorna null se o usuario cancelou o seletor de conta do google
  Future<UserCredential?> entrarComGoogle() async {
    await _garantirGoogleSignInInicializado();
    try {
      final contaGoogle = await GoogleSignIn.instance.authenticate();
      final auth = contaGoogle.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<void> sair() async {
    await _auth.signOut();
    if (_googleSignInPronto) await GoogleSignIn.instance.signOut();
  }

  Future<void> enviarEmailDeVerificacao() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // manda o SMS com o codigo -- verificationCompleted so dispara sozinho em
  // alguns aparelhos Android (auto-retrieval), o normal e esperar o codigo
  // chegar e confirmar na mao com confirmarCodigoTelefone
  Future<void> verificarTelefone({
    required String numeroCompleto,
    required void Function(String verificationId) aoCodigoEnviado,
    required void Function(String erro) aoFalhar,
    required VoidCallback aoVerificarAutomaticamente,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: numeroCompleto,
      verificationCompleted: (credential) async {
        try {
          await _auth.currentUser?.linkWithCredential(credential);
          aoVerificarAutomaticamente();
        } catch (e) {
          aoFalhar('Erro ao confirmar automaticamente: $e');
        }
      },
      verificationFailed: (e) => aoFalhar(e.message ?? 'Não foi possível enviar o código.'),
      codeSent: (verificationId, resendToken) => aoCodigoEnviado(verificationId),
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  // liga o numero verificado a conta ja logada (nao troca de usuario)
  Future<void> confirmarCodigoTelefone(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    await _auth.currentUser?.linkWithCredential(credential);
  }
}
