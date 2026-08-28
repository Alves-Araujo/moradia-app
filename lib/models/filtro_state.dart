import 'package:flutter/foundation.dart';

// gerencia o estado dos filtros do mapa
class FiltroState extends ChangeNotifier {
  double _precoMaximo = 3000; // 3000 = sem filtro (maximo do slider)
  List<String> _tagsSelecionadas = [];
  String? _cidadeSelecionada; // null = todas as cidades

  double get precoMaximo => _precoMaximo;
  List<String> get tagsSelecionadas => List.unmodifiable(_tagsSelecionadas);
  String? get cidadeSelecionada => _cidadeSelecionada;

  bool get temFiltrosAtivos =>
      _precoMaximo < 3000 || _tagsSelecionadas.isNotEmpty || _cidadeSelecionada != null;

  void aplicarEstado({required double preco, required List<String> tags, String? cidade}) {
    _precoMaximo = preco;
    _tagsSelecionadas = List.from(tags);
    _cidadeSelecionada = cidade;
    notifyListeners();
  }
}
