import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoListing { moradia, evento }

class Imovel {
  final String id;
  final String titulo;
  final String descricao;
  final double preco;
  final LatLng posicao;
  final TipoListing tipo;
  final List<String> tags;
  final String endereco;
  final List<String> fotos;

  Imovel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.preco,
    required this.posicao,
    required this.tipo,
    required this.tags,
    required this.endereco,
    this.fotos = const [],
  });

  factory Imovel.fromMap(Map<String, dynamic> map, String docId) {
    double lat = 0.0;
    double lng = 0.0;

    if (map['posicao'] != null) {
      if (map['posicao'] is GeoPoint) {
        lat = (map['posicao'] as GeoPoint).latitude;
        lng = (map['posicao'] as GeoPoint).longitude;
      } else {
        try {
          lat = map['posicao']['lat'] ?? 0.0;
          lng = map['posicao']['lng'] ?? 0.0;
        } catch (_) {}
      }
    }

    return Imovel(
      id: docId,
      titulo: map['titulo'] ?? '',
      descricao: map['descricao'] ?? '',
      preco: (map['preco'] ?? 0.0).toDouble(),
      posicao: LatLng(lat, lng),
      tipo: (map['tipo'] ?? '') == 'evento' ? TipoListing.evento : TipoListing.moradia,
      tags: List<String>.from(map['tags'] ?? []),
      endereco: map['endereco'] ?? '',
      fotos: List<String>.from(map['fotos'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'preco': preco,
      'posicao': GeoPoint(posicao.latitude, posicao.longitude),
      'tipo': tipo == TipoListing.evento ? 'evento' : 'moradia',
      'tags': tags,
      'endereco': endereco,
      'fotos': fotos,
    };
  }
}