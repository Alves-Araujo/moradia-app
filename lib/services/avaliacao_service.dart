import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/avaliacao.dart';

// avaliacoes ficam numa subcolecao dentro de quem foi avaliado --
// "usuarios/{uid}/avaliacoes" ou "imobiliarias/{id}/avaliacoes"
class AvaliacaoService {
  AvaliacaoService._();
  static final AvaliacaoService instance = AvaliacaoService._();

  CollectionReference<Map<String, dynamic>> _colecao(String colecaoPai, String id) {
    return FirebaseFirestore.instance.collection(colecaoPai).doc(id).collection('avaliacoes');
  }

  Future<void> enviarAvaliacao({
    required String colecaoPai,
    required String avaliadoId,
    required Avaliacao avaliacao,
  }) {
    return _colecao(colecaoPai, avaliadoId).add(avaliacao.toMap());
  }

  Stream<List<Avaliacao>> streamAvaliacoes(String colecaoPai, String avaliadoId) {
    return _colecao(colecaoPai, avaliadoId)
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Avaliacao.fromMap(d.data(), d.id)).toList());
  }
}
