// formata um valor em reais no padrao brasileiro "R$1.200,00" (ponto no
// milhar, virgula nos centavos) -- sem depender do pacote intl so pra isso
String formatarPreco(double valor) {
  final inteiro = valor.truncate().abs();
  final centavos = ((valor - valor.truncate()) * 100).round().abs();
  final inteiroStr = inteiro.toString();

  final comPontos = StringBuffer();
  for (var i = 0; i < inteiroStr.length; i++) {
    final posicaoDaDireita = inteiroStr.length - i;
    if (i > 0 && posicaoDaDireita % 3 == 0) comPontos.write('.');
    comPontos.write(inteiroStr[i]);
  }

  final sinal = valor < 0 ? '-' : '';
  return 'R\$$sinal$comPontos,${centavos.toString().padLeft(2, '0')}';
}
