import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/imobiliaria.dart';
import '../models/perfil_publico.dart';
import '../utils/moderacao.dart';

class ImobiliariaService {
  ImobiliariaService._();
  static final ImobiliariaService instance = ImobiliariaService._();

  final _colecao = FirebaseFirestore.instance.collection('imobiliarias');

  static String normalizarCnpj(String cnpj) => cnpj.replaceAll(RegExp(r'\D'), '');

  Future<Imobiliaria?> buscarPorId(String id) async {
    if (id.isEmpty) return null;
    final doc = await _colecao.doc(id).get();
    if (!doc.exists) return null;
    return Imobiliaria.fromMap(doc.data()!, doc.id);
  }

  // acha a imobiliaria pelo cnpj ou cria uma nova, pendente de confirmacao --
  // retorna o id (usado como "imobiliariaId" no perfil do corretor)
  Future<String> encontrarOuCriar({
    required String nome,
    required String cnpj,
    required String email,
    required String endereco,
  }) async {
    final cnpjBusca = normalizarCnpj(cnpj);
    final existente = await _colecao.where('cnpjBusca', isEqualTo: cnpjBusca).limit(1).get();
    if (existente.docs.isNotEmpty) return existente.docs.first.id;

    final novaImobiliaria = Imobiliaria(
      id: '',
      nome: nome,
      nomeBusca: normalizarNome(nome),
      cnpj: cnpj,
      cnpjBusca: cnpjBusca,
      email: email,
      emailBusca: email.toLowerCase().trim(),
    );
    final doc = await _colecao.add(novaImobiliaria.toMap());
    return doc.id;
  }

  // pendente = ainda nao confirmada por ninguem que tenha esse e-mail
  Future<Imobiliaria?> buscarPendentePorEmail(String email) async {
    final emailBusca = email.toLowerCase().trim();
    final query = await _colecao.where('emailBusca', isEqualTo: emailBusca).limit(1).get();
    if (query.docs.isEmpty) return null;
    final imobiliaria = Imobiliaria.fromMap(query.docs.first.data(), query.docs.first.id);
    return imobiliaria.emailVerificado ? null : imobiliaria;
  }

  // confirma a imobiliaria e libera o vinculo de todos os corretores que ja
  // tinham apontado pra ela. So mexe na colecao publica -- quem confirma nao
  // e o dono do perfil do corretor, entao nao pode escrever em "usuarios"
  // dele (o proprio corretor sincroniza esse campo de volta da proxima vez
  // que abrir/salvar o perfil)
  Future<void> confirmar(String imobiliariaId) async {
    await _colecao.doc(imobiliariaId).update({'emailVerificado': true});

    final corretores = await FirebaseFirestore.instance
        .collection('perfisPublicos')
        .where('imobiliariaId', isEqualTo: imobiliariaId)
        .get();

    final lote = FirebaseFirestore.instance.batch();
    for (final doc in corretores.docs) {
      lote.set(doc.reference, {'vinculoConfirmado': true}, SetOptions(merge: true));
    }
    await lote.commit();
  }

  // corretores confirmados dessa imobiliaria -- le da colecao publica (nao
  // da "usuarios", que so o proprio dono pode ler); filtro de confirmado
  // feito aqui pra nao precisar de indice composto no firestore
  Stream<List<PerfilPublico>> streamCorretoresVinculados(String imobiliariaId) {
    return FirebaseFirestore.instance
        .collection('perfisPublicos')
        .where('imobiliariaId', isEqualTo: imobiliariaId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PerfilPublico.fromMap(d.data(), d.id))
            .where((p) => p.vinculoConfirmado)
            .toList());
  }
}
