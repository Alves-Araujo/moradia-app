import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/imovel.dart';
import '../utils/moderacao.dart';

enum TipoSugestao { cidade, faculdade, moradia }

class SugestaoBusca {
  final String texto;
  final TipoSugestao tipo;
  final LatLng destino;

  SugestaoBusca({required this.texto, required this.tipo, required this.destino});
}

class _LocalConhecido {
  final String nome;
  final TipoSugestao tipo;
  final LatLng posicao;
  const _LocalConhecido(this.nome, this.tipo, this.posicao);
}

// cidades e faculdades da regiao do Inatel (Santa Rita do Sapucaí, MG) --
// lista estatica, sem custo de leitura nenhuma
final List<String> locaisConhecidosParaCidade = _locaisConhecidos
    .where((l) => l.tipo == TipoSugestao.cidade)
    .map((l) => l.nome)
    .toList();

// mesma lista, mas com a coordenada junto -- usada no seletor de destino da rota
final List<SugestaoBusca> locaisConhecidosGeral = _locaisConhecidos
    .map((l) => SugestaoBusca(texto: l.nome, tipo: l.tipo, destino: l.posicao))
    .toList();

const List<_LocalConhecido> _locaisConhecidos = [
  _LocalConhecido('Inatel', TipoSugestao.faculdade, LatLng(-22.2528, -45.6976)),
  _LocalConhecido('Santa Rita do Sapucaí, MG', TipoSugestao.cidade, LatLng(-22.2528, -45.6976)),
  _LocalConhecido('Cássia, MG', TipoSugestao.cidade, LatLng(-20.5967, -46.9219)),
  _LocalConhecido('Itajubá, MG', TipoSugestao.cidade, LatLng(-22.4256, -45.4528)),
  _LocalConhecido('Pouso Alegre, MG', TipoSugestao.cidade, LatLng(-22.2299, -45.9364)),
  _LocalConhecido('Poços de Caldas, MG', TipoSugestao.cidade, LatLng(-21.7877, -46.5613)),
  _LocalConhecido('São Lourenço, MG', TipoSugestao.cidade, LatLng(-22.1170, -45.0547)),
  _LocalConhecido('UNIFEI - Universidade Federal de Itajubá', TipoSugestao.faculdade, LatLng(-22.4162, -45.4467)),
  _LocalConhecido('FAI - Faculdade de Administração e Informática', TipoSugestao.faculdade, LatLng(-22.2481, -45.6928)),
];

// combina cidades/faculdades (lista fixa) com moradias (ja carregadas em
// memoria pelo mapa) -- nenhuma leitura nova no firestore por busca
class BuscaService {
  BuscaService._();
  static final BuscaService instance = BuscaService._();

  List<SugestaoBusca> buscarSugestoes(String query, List<Imovel> imoveis) {
    final termo = normalizarNome(query);
    if (termo.isEmpty) return [];

    final sugestoes = <SugestaoBusca>[];

    for (final local in _locaisConhecidos) {
      if (normalizarNome(local.nome).contains(termo)) {
        sugestoes.add(SugestaoBusca(texto: local.nome, tipo: local.tipo, destino: local.posicao));
      }
    }

    for (final imovel in imoveis) {
      // combina titulo, endereco, tipo (Casa/Apartamento/Pensão/...) e cidade
      // -- antes so titulo+endereco batiam, entao buscar "pensao" nao achava
      // uma Pensão cujo titulo/endereco nao continha essa palavra
      final combinado = normalizarNome(
        '${imovel.titulo} ${imovel.endereco} ${imovel.tipoImovel} ${imovel.cidade}',
      );
      if (combinado.contains(termo)) {
        sugestoes.add(SugestaoBusca(texto: imovel.titulo, tipo: TipoSugestao.moradia, destino: imovel.posicao));
      }
    }

    return sugestoes.take(8).toList();
  }

  // autocomplete de cidade/regiao de verdade (nao so a listinha fixa acima),
  // via Nominatim (OpenStreetMap) -- gratuito, sem chave, sem depender do
  // Google Cloud. Limitado ao Brasil pra nao trazer resultado de fora
  Future<List<SugestaoBusca>> buscarCidadesOnline(String query) async {
    if (query.trim().length < 3) return [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'countrycodes': 'br',
      'limit': '6',
    });

    try {
      final resposta = await http
          .get(uri, headers: {'User-Agent': 'moradia-app-inatel/1.0'})
          .timeout(const Duration(seconds: 6));
      if (resposta.statusCode != 200) return [];

      final lista = json.decode(resposta.body) as List<dynamic>;
      final vistos = <String>{};
      final sugestoes = <SugestaoBusca>[];

      for (final item in lista) {
        final endereco = item['address'] as Map<String, dynamic>? ?? {};
        final cidade = endereco['city'] ?? endereco['town'] ?? endereco['village'] ?? endereco['municipality'];
        final estado = endereco['state'];
        if (cidade == null) continue;

        final texto = estado != null ? '$cidade, $estado' : '$cidade';
        if (!vistos.add(texto)) continue; // ja apareceu (nominatim repete cidade por bairro)

        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lng == null) continue;

        sugestoes.add(SugestaoBusca(texto: texto, tipo: TipoSugestao.cidade, destino: LatLng(lat, lng)));
      }
      return sugestoes;
    } catch (e) {
      debugPrint('Erro ao buscar cidades online: $e');
      return [];
    }
  }
}
