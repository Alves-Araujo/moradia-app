import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monitoria.dart';

// so a estrutura pronta por enquanto, sem tela ainda -- pra usarmos quando
// formos implementar as monitorias de verdade
class MonitoriaService {
  MonitoriaService._();
  static final MonitoriaService instance = MonitoriaService._();

  final _colecao = FirebaseFirestore.instance.collection('monitorias');

  Future<void> criarMonitoria(Monitoria monitoria) {
    return _colecao.add(monitoria.toMap());
  }

  Stream<List<Monitoria>> streamMonitorias() {
    return _colecao.orderBy('criadoEm', descending: true).snapshots().map(
          (snap) => snap.docs.map((doc) => Monitoria.fromMap(doc.data(), doc.id)).toList(),
        );
  }
}
