// endereco estruturado generico -- usado em qualquer fluxo do sistema que
// precise de endereco completo (imovel, perfil do usuario, responsavel,
// dados da empresa...), sempre com os mesmos 7 componentes. Cada dono decide
// como as chaves ficam salvas no Firestore (prefixo/sufixo) passando uma
// funcao pro fromMap/toMap, pra encaixar na convencao ja usada em cada doc
class Endereco {
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String cidade;
  final String estado;

  const Endereco({
    this.cep = '',
    this.logradouro = '',
    this.numero = '',
    this.complemento = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
  });

  // tudo obrigatorio menos o complemento (nem todo imovel/casa tem)
  bool get completo =>
      cep.isNotEmpty && logradouro.isNotEmpty && numero.isNotEmpty &&
      bairro.isNotEmpty && cidade.isNotEmpty && estado.isNotEmpty;

  bool get vazio =>
      cep.isEmpty && logradouro.isEmpty && numero.isEmpty &&
      complemento.isEmpty && bairro.isEmpty && cidade.isEmpty && estado.isEmpty;

  // string corrida, pras telas que so mostram "o endereco" como texto direto
  String get formatado {
    final partes = <String>[
      '$logradouro${numero.isNotEmpty ? ', $numero' : ''}',
      if (complemento.isNotEmpty) complemento,
      bairro,
      '$cidade - $estado',
      if (cep.isNotEmpty) 'CEP $cep',
    ];
    return partes.where((p) => p.trim().isNotEmpty).join(', ');
  }

  factory Endereco.fromMap(Map<String, dynamic> map, String Function(String campo) chave) {
    String c(String nome) => map[chave(nome)] ?? '';
    return Endereco(
      cep: c('Cep'),
      logradouro: c('Logradouro'),
      numero: c('Numero'),
      complemento: c('Complemento'),
      bairro: c('Bairro'),
      cidade: c('Cidade'),
      estado: c('Estado'),
    );
  }

  Map<String, dynamic> toMap(String Function(String campo) chave) {
    return {
      chave('Cep'): cep,
      chave('Logradouro'): logradouro,
      chave('Numero'): numero,
      chave('Complemento'): complemento,
      chave('Bairro'): bairro,
      chave('Cidade'): cidade,
      chave('Estado'): estado,
    };
  }
}
