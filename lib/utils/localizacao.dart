import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// pede permissao (se precisar) e devolve a posicao atual do gps -- null se o
// usuario negou ou o servico de localizacao ta desligado
Future<LatLng?> obterLocalizacaoAtual() async {
  final servicoAtivo = await Geolocator.isLocationServiceEnabled();
  if (!servicoAtivo) return null;

  var permissao = await Geolocator.checkPermission();
  if (permissao == LocationPermission.denied) {
    permissao = await Geolocator.requestPermission();
    if (permissao == LocationPermission.denied) return null;
  }
  if (permissao == LocationPermission.deniedForever) return null;

  final posicao = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return LatLng(posicao.latitude, posicao.longitude);
}
