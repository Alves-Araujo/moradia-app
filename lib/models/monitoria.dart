import 'package:cloud_firestore/cloud_firestore.dart';

// estrutura basica pra quando formos implementar as monitorias de verdade
class Monitoria {
  final String id;
  final String titulo;
  final String disciplina;
  final String descricao;
  final String monitorUid;
  final DateTime? criadoEm;

  Monitoria({
    required this.id,
    required this.titulo,
    required this.disciplina,
    required this.descricao,
    required this.monitorUid,
    this.criadoEm,
  });

  factory Monitoria.fromMap(Map<String, dynamic> map, String id) {
    return Monitoria(
      id: id,
      titulo: map['titulo'] ?? '',
      disciplina: map['disciplina'] ?? '',
      descricao: map['descricao'] ?? '',
      monitorUid: map['monitorUid'] ?? '',
      criadoEm: (map['criadoEm'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'disciplina': disciplina,
      'descricao': descricao,
      'monitorUid': monitorUid,
      'criadoEm': FieldValue.serverTimestamp(),
    };
  }
}
