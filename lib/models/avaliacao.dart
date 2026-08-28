import 'package:cloud_firestore/cloud_firestore.dart';

class Avaliacao {
  final String id;
  final String avaliadorUid;
  final String avaliadorNome;
  final String avaliadorFotoUrl;
  final int nota; // 1 a 5
  final String comentario;
  final DateTime? criadoEm;

  Avaliacao({
    required this.id,
    required this.avaliadorUid,
    required this.avaliadorNome,
    this.avaliadorFotoUrl = '',
    required this.nota,
    this.comentario = '',
    this.criadoEm,
  });

  factory Avaliacao.fromMap(Map<String, dynamic> map, String id) {
    final notaBruta = map['nota'];
    return Avaliacao(
      id: id,
      avaliadorUid: map['avaliadorUid'] ?? '',
      avaliadorNome: map['avaliadorNome'] ?? '',
      avaliadorFotoUrl: map['avaliadorFotoUrl'] ?? '',
      nota: notaBruta is int ? notaBruta : (notaBruta as num? ?? 0).toInt(),
      comentario: map['comentario'] ?? '',
      criadoEm: (map['criadoEm'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'avaliadorUid': avaliadorUid,
      'avaliadorNome': avaliadorNome,
      'avaliadorFotoUrl': avaliadorFotoUrl,
      'nota': nota,
      'comentario': comentario,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }
}
