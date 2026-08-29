import 'package:flutter/foundation.dart';

// filtro de cidade/regiao -- global (mesmo padrao do temaGlobal) de proposito:
// precisa valer pro app inteiro (mapa E a lista da aba Resumo), nao so pra
// uma instancia do FiltroState que fica presa a tela do mapa (e e recriada
// toda vez que troca de aba, ver comentario em rota_service.dart)
final ValueNotifier<String?> cidadeFiltroGlobal = ValueNotifier(null);

// gerencia o estado dos filtros do mapa (preco e tags -- esses sim so
// importam pros markers do mapa, entao ficam locais mesmo)
class FiltroState extends ChangeNotifier {
  double _precoMaximo = 3000; // 3000 = sem filtro (maximo do slider)
  List<String> _tagsSelecionadas = [];

  double get precoMaximo => _precoMaximo;
  List<String> get tagsSelecionadas => List.unmodifiable(_tagsSelecionadas);

  bool get temFiltrosAtivos =>
      _precoMaximo < 3000 || _tagsSelecionadas.isNotEmpty || cidadeFiltroGlobal.value != null;

  void aplicarEstado({required double preco, required List<String> tags}) {
    _precoMaximo = preco;
    _tagsSelecionadas = List.from(tags);
    notifyListeners();
  }
}
