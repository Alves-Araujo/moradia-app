import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/perfil_publico.dart';
import '../models/usuario.dart';

// espelha os campos nao-sensiveis do Usuario numa colecao separada, legivel
// por qualquer pessoa logada (busca, chat, avaliacoes, perfil publico...)
class PerfilPublicoService {
  PerfilPublicoService._();
  static final PerfilPublicoService instance = PerfilPublicoService._();

  final _colecao = FirebaseFirestore.instance.collection('perfisPublicos');

  Future<void> sincronizar(Usuario usuario) {
    return _colecao.doc(usuario.uid).set({
      'nome': usuario.nome,
      'nomeBusca': usuario.nomeBusca,
      'fotoUrl': usuario.fotoUrl,
      'tipoUsuario': usuario.tipoUsuario,
      'subtipoCorretor': usuario.subtipoCorretor,
      'cidade': usuario.cidade,
      'imobiliariaId': usuario.imobiliariaId,
      'vinculoConfirmado': usuario.vinculoConfirmado,
    }, SetOptions(merge: true));
  }

  Future<void> atualizarUltimoAcesso(String uid) {
    return _colecao.doc(uid).set({'ultimoAcesso': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<PerfilPublico?> buscarPorUid(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _colecao.doc(uid).get();
    if (!doc.exists) return null;
    return PerfilPublico.fromMap(doc.data()!, doc.id);
  }

  // prefixo do nome (mesma tecnica usada no filtro de moradias por texto)
  Future<List<PerfilPublico>> buscarPorPrefixoDeNome(String termo, {int limite = 10}) async {
    if (termo.isEmpty) return [];
    final query = await _colecao
        .orderBy('nomeBusca')
        .startAt([termo])
        .endAt(['$termo'])
        .limit(limite)
        .get();
    return query.docs.map((d) => PerfilPublico.fromMap(d.data(), d.id)).toList();
  }
}
