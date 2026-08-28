import 'package:flutter/foundation.dart' show ValueNotifier;
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

// wrapper fino sobre o flutter_polyline_points pra buscar a rota entre 2 pontos
class RotaService {
  RotaService(this._apiKey);
  final String _apiKey;

  Future<RotaResultado?> buscarRota({required LatLng origem, required LatLng destino}) async {
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

    if (resultado.points.isEmpty) return null;

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
