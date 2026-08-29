import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/imovel.dart';
import '../utils/moderacao.dart';

enum TipoSugestao { cidade, faculdade, moradia, endereco }

// forma da geometria devolvida pro mapa desenhar o destaque certo --
// ponto vira marker, linha vira Polyline (rua), area vira Polygon (bairro)
enum TipoGeometria { ponto, linha, area }

class SugestaoBusca {
  final String texto;
  final TipoSugestao tipo;
  final LatLng destino;
  final TipoGeometria tipoGeometria;
  final List<LatLng> pontosGeometria; // so preenchido quando tipoGeometria != ponto

  SugestaoBusca({
    required this.texto,
    required this.tipo,
    required this.destino,
    this.tipoGeometria = TipoGeometria.ponto,
    this.pontosGeometria = const [],
  });
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

// mesma lista, mas com a coordenada junto -- usada no seletor de destino da
// rota e no "voar pra cidade parceira" (esse ultimo so navega a camera, nunca filtra)
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

  // autocomplete de verdade (ruas, bairros, cidades -- nao so a listinha fixa
  // acima), via Nominatim (OpenStreetMap) -- gratuito, sem chave, sem
  // depender do Google Cloud (que na pratica so aceita Directions/Places com
  // billing habilitado e sem restricao de API, o que ficou instavel pra
  // gente). Limitado ao Brasil pra nao trazer resultado de fora.
  // polygon_geojson pede a geometria de verdade (contorno da rua/bairro), nao
  // so o ponto central -- e o que permite desenhar o destaque certo no mapa
  Future<List<SugestaoBusca>> buscarLocaisOnline(String query) async {
    if (query.trim().length < 3) return [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'countrycodes': 'br',
      'limit': '8',
      'polygon_geojson': '1',
      'polygon_threshold': '0.002', // simplifica o contorno, senao vem pesado demais
    });

    try {
      final resposta = await http
          .get(uri, headers: {'User-Agent': 'moradia-app-inatel/1.0'})
          .timeout(const Duration(seconds: 6));
      if (resposta.statusCode != 200) return [];

      final lista = json.decode(resposta.body) as List<dynamic>;
      final vistos = <String>{};
      final sugestoes = <SugestaoBusca>[];

      const tiposDeCidade = {'city', 'town', 'village', 'municipality', 'suburb'};

      for (final item in lista) {
        // display_name ja vem formatado pelo Nominatim (rua, bairro, cidade,
        // estado...) -- usar direto em vez de remontar a mao a partir de
        // "address" cobre ruas/bairros que antes ficavam de fora
        final texto = item['display_name'] as String?;
        if (texto == null || texto.isEmpty || !vistos.add(texto)) continue;

        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lng == null) continue;

        final classe = item['class'] as String? ?? '';
        final tipoOsm = item['type'] as String? ?? '';
        final ehCidade = classe == 'place' && tiposDeCidade.contains(tipoOsm);

        final geometria = _extrairGeometria(item['geojson'] as Map<String, dynamic>?);

        sugestoes.add(SugestaoBusca(
          texto: texto,
          tipo: ehCidade ? TipoSugestao.cidade : TipoSugestao.endereco,
          destino: LatLng(lat, lng),
          tipoGeometria: geometria.$1,
          pontosGeometria: geometria.$2,
        ));
      }
      return sugestoes;
    } catch (e) {
      debugPrint('Erro ao buscar locais online: $e');
      return [];
    }
  }

  // decodifica o geojson que o Nominatim devolve -- rua vira LineString
  // (as vezes MultiLineString, quando tem mais de um trecho), bairro/regiao
  // vira Polygon/MultiPolygon, ponto isolado (loja, predio...) fica so ponto mesmo
  (TipoGeometria, List<LatLng>) _extrairGeometria(Map<String, dynamic>? geojson) {
    if (geojson == null) return (TipoGeometria.ponto, const <LatLng>[]);

    List<LatLng> anel(List<dynamic> pontos) => pontos
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();

    final tipo = geojson['type'] as String?;
    final coordenadas = geojson['coordinates'];
    if (coordenadas == null) return (TipoGeometria.ponto, const <LatLng>[]);

    try {
      switch (tipo) {
        case 'LineString':
          return (TipoGeometria.linha, anel(coordenadas as List<dynamic>));
        case 'MultiLineString':
          final pontos = (coordenadas as List<dynamic>)
              .expand((trecho) => anel(trecho as List<dynamic>))
              .toList();
          return (TipoGeometria.linha, pontos);
        case 'Polygon':
          final anelExterno = (coordenadas as List<dynamic>).first as List<dynamic>;
          return (TipoGeometria.area, anel(anelExterno));
        case 'MultiPolygon':
          final poligonos = (coordenadas as List<dynamic>)
              .map((p) => anel((p as List<dynamic>).first as List<dynamic>))
              .toList();
          poligonos.sort((a, b) => b.length.compareTo(a.length));
          return (TipoGeometria.area, poligonos.first);
        default:
          return (TipoGeometria.ponto, const <LatLng>[]);
      }
    } catch (_) {
      return (TipoGeometria.ponto, const <LatLng>[]);
    }
  }
}
