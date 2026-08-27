import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';
import '../utils/moderacao.dart';

class UsuarioService {
  UsuarioService._();
  static final UsuarioService instance = UsuarioService._();

  final _colecao = FirebaseFirestore.instance.collection('usuarios');

  Future<Usuario?> buscarPorUid(String uid) async {
    final doc = await _colecao.doc(uid).get();
    if (!doc.exists) return null;
    return Usuario.fromMap(doc.data()!, doc.id);
  }

  // cria o perfil minimo -- tipo de conta e o resto dos dados so vem depois,
  // na tela de completar perfil
  Future<void> criarPerfil({
    required String uid,
    required String nome,
    required String email,
  }) {
    return _colecao.doc(uid).set({
      'nome': nome,
      'nomeBusca': normalizarNome(nome),
      'email': email,
      'tipoUsuario': '',
      'fotoUrl': '',
      'perfilCompleto': false,
      'dataCriacao': FieldValue.serverTimestamp(),
    });
  }

  // true se ja existe outro usuario com esse nome (comparacao normalizada)
  Future<bool> nomeJaExiste(String nome, {String? ignorarUid}) async {
    final normalizado = normalizarNome(nome);
    final query = await _colecao.where('nomeBusca', isEqualTo: normalizado).get();
    return query.docs.any((doc) => doc.id != ignorarUid);
  }

  Future<void> atualizarPerfil(String uid, {String? nome, String? fotoUrl}) {
    final dados = <String, dynamic>{};
    if (nome != null) {
      dados['nome'] = nome;
      dados['nomeBusca'] = normalizarNome(nome);
    }
    if (fotoUrl != null) dados['fotoUrl'] = fotoUrl;
    if (dados.isEmpty) return Future.value();
    return _colecao.doc(uid).update(dados);
  }

  // grava o formulario inteiro de "concluir perfil" de uma vez
  Future<void> completarPerfil(Usuario usuario) {
    return _colecao.doc(usuario.uid).update(usuario.toMap());
  }
}
