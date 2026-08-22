import 'package:flutter/foundation.dart';

/// Gerencia o estado dos filtros do mapa.
/// Notifica listeners (ex.: a tela de mapa) quando os filtros mudam.
class FiltroState extends ChangeNotifier {
  double _precoMaximo = 3000; // 3000 = sem filtro (slider vai até 3000)
  List<String> _tagsSelecionadas = [];

  double get precoMaximo => _precoMaximo;
  List<String> get tagsSelecionadas => List.unmodifiable(_tagsSelecionadas);

  /// Retorna `true` se algum filtro está diferente do padrão (tudo visível).
  bool get temFiltrosAtivos =>
      _precoMaximo < 3000 || _tagsSelecionadas.isNotEmpty;

  /// Aplica novos valores de preço e tags e notifica listeners.
  void aplicarEstado({required double preco, required List<String> tags}) {
    _precoMaximo = preco;
    _tagsSelecionadas = List.from(tags);
    notifyListeners();
  }
}
