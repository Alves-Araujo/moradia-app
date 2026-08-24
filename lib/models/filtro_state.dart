import 'package:flutter/foundation.dart';

// gerencia o estado dos filtros do mapa
class FiltroState extends ChangeNotifier {
  double _precoMaximo = 3000; // 3000 = sem filtro (maximo do slider)
  List<String> _tagsSelecionadas = [];

  double get precoMaximo => _precoMaximo;
  List<String> get tagsSelecionadas => List.unmodifiable(_tagsSelecionadas);

  bool get temFiltrosAtivos =>
      _precoMaximo < 3000 || _tagsSelecionadas.isNotEmpty;

  void aplicarEstado({required double preco, required List<String> tags}) {
    _precoMaximo = preco;
    _tagsSelecionadas = List.from(tags);
    notifyListeners();
  }
}
