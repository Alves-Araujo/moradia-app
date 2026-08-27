import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

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
}
