import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng, LatLngBounds;

// pedido de rota feito na tela de detalhes, consumido pelo mapa principal --
// mesmo padrao do temaGlobal (ValueNotifier global) ja usado no app. A tela
// de detalhes seta o valor e volta pro mapa; o mapa escuta, calcula a rota
// de verdade e limpa o valor
class RotaPendente {
  final LatLng origem;
  final LatLng destino;
  final String nomeDestino;

  RotaPendente({required this.origem, required this.destino, required this.nomeDestino});
}

final ValueNotifier<RotaPendente?> rotaPendenteGlobal = ValueNotifier(null);

class RotaResultado {
  final List<LatLng> pontos;
  final String distanciaTexto;
  final String duracaoTexto;

  RotaResultado({
    required this.pontos,
    required this.distanciaTexto,
    required this.duracaoTexto,
  });
}

// rota ja calculada, pronta pra desenhar -- guarda tambem origem/destino
// (os markers) e o nome digitado/escolhido pro destino, pro card de
// distancia/duracao mostrar
class RotaAtiva {
  final RotaResultado resultado;
  final LatLng origem;
  final LatLng destino;
  final String nomeDestino;

  RotaAtiva({
    required this.resultado,
    required this.origem,
    required this.destino,
    required this.nomeDestino,
  });
}

// resultado da rota mais recente e se uma busca ta em andamento -- ficam
// globais (mesmo padrao do temaGlobal) de proposito: o CentroDoMapa e
// recriado do zero toda vez que o usuario troca de aba (a TelaPrincipal usa
// uma key baseada no indice na IndexedStack), entao guardar isso preso a
// State dele faria o resultado se perder se o calculo terminasse com o
// mapa fora da tela
final ValueNotifier<bool> rotaCarregandoGlobal = ValueNotifier(false);
final ValueNotifier<RotaAtiva?> rotaAtivaGlobal = ValueNotifier(null);

// mensagem de erro da ultima tentativa de rota -- o mapa escuta isso pra
// mostrar um SnackBar (antes uma falha aqui sumia sem avisar ninguem)
final ValueNotifier<String?> rotaErroGlobal = ValueNotifier(null);

// dispara o calculo de uma rota pendente e publica o resultado -- funcao
// solta, sem dono, pra nao ser interrompida se a tela que a chamou for
// desmontada no meio do caminho
Future<void> processarPedidoDeRota(RotaPendente pendente, String apiKey) async {
  rotaCarregandoGlobal.value = true;
  try {
    final resultado = await RotaService(apiKey).buscarRota(origem: pendente.origem, destino: pendente.destino);
    rotaAtivaGlobal.value = RotaAtiva(
      resultado: resultado,
      origem: pendente.origem,
      destino: pendente.destino,
      nomeDestino: pendente.nomeDestino,
    );
  } catch (e) {
    debugPrint('Erro ao calcular rota: $e');
    rotaErroGlobal.value = e.toString();
  } finally {
    rotaCarregandoGlobal.value = false;
  }
}

// wrapper fino sobre o flutter_polyline_points pra buscar a rota entre 2 pontos
class RotaService {
  RotaService(this._apiKey);
  final String _apiKey;

  Future<RotaResultado> buscarRota({required LatLng origem, required LatLng destino}) async {
    final polylinePoints = PolylinePoints(apiKey: _apiKey);

    // PolylineRequest usa a Directions API "classica" de proposito -- foi ela
    // que habilitamos no google cloud, nao a Routes API nova (que o pacote
    // tambem suporta, mas exigiria habilitar outra api)
    final resultado = await polylinePoints.getRouteBetweenCoordinates(
      // ignore: deprecated_member_use
      request: PolylineRequest(
        origin: PointLatLng(origem.latitude, origem.longitude),
        destination: PointLatLng(destino.latitude, destino.longitude),
        mode: TravelMode.driving,
      ),
    );

    // antes isso so virava um "null" silencioso -- agora propaga o motivo
    // de verdade (status + mensagem que o Google devolveu), essencial pra
    // descobrir problema de chave de API/restricao/limite
    if (resultado.points.isEmpty) {
      throw Exception('${resultado.status ?? 'Sem rota'}: ${resultado.errorMessage ?? 'nenhum trajeto encontrado'}');
    }

    return RotaResultado(
      pontos: resultado.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      distanciaTexto: resultado.distanceTexts?.first ?? '',
      duracaoTexto: resultado.durationTexts?.first ?? '',
    );
  }

  // menor retangulo que engloba todos os pontos da rota, pra enquadrar a
  // camera do mapa mostrando o trajeto inteiro
  static LatLngBounds calcularBounds(List<LatLng> pontos) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pontos) {
      minLat = (minLat == null || p.latitude < minLat) ? p.latitude : minLat;
      maxLat = (maxLat == null || p.latitude > maxLat) ? p.latitude : maxLat;
      minLng = (minLng == null || p.longitude < minLng) ? p.longitude : minLng;
      maxLng = (maxLng == null || p.longitude > maxLng) ? p.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
}
