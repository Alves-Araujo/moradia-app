// lista curta de palavroes mais comuns em pt-br -- da pra crescer depois
const List<String> _palavroesConhecidos = [
  'porra', 'caralho', 'merda', 'buceta', 'piroca', 'pinto', 'puta', 'putaria',
  'viado', 'bicha', 'cuzao', 'cu', 'fdp', 'arrombado', 'arrombada', 'corno',
  'desgraca', 'imbecil', 'retardado', 'babaca', 'otario', 'otaria', 'idiota',
  'vagabundo', 'vagabunda', 'safado', 'safada', 'escroto', 'escrota',
];

// tira acento de uma string, pra comparacao mais tolerante
String semAcento(String texto) {
  const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const semAcentoEquivalente = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  var resultado = texto;
  for (var i = 0; i < comAcento.length; i++) {
    resultado = resultado.replaceAll(comAcento[i], semAcentoEquivalente[i]);
  }
  return resultado;
}

// nome normalizado (minusculo, sem acento, sem espaco duplicado) -- usado
// pra checar duplicidade e pra busca
String normalizarNome(String nome) {
  return semAcento(nome.trim().toLowerCase()).replaceAll(RegExp(r'\s+'), ' ');
}

bool temNomeESobrenome(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.length >= 2).toList();
  return partes.length >= 2;
}

bool contemPalavraImpropria(String nome) {
  final palavras = normalizarNome(nome).split(' ');
  return palavras.any((p) => _palavroesConhecidos.contains(p));
}
