class Imobiliaria {
  final String id;
  final String nome;
  final String nomeBusca;
  final String cnpj;
  final String cnpjBusca;
  final String email;
  final String emailBusca;
  final bool emailVerificado;
  final String fotoUrl;
  final String endereco;

  Imobiliaria({
    required this.id,
    required this.nome,
    this.nomeBusca = '',
    required this.cnpj,
    this.cnpjBusca = '',
    required this.email,
    this.emailBusca = '',
    this.emailVerificado = false,
    this.fotoUrl = '',
    this.endereco = '',
  });

  factory Imobiliaria.fromMap(Map<String, dynamic> map, String id) {
    return Imobiliaria(
      id: id,
      nome: map['nome'] ?? '',
      nomeBusca: map['nomeBusca'] ?? '',
      cnpj: map['cnpj'] ?? '',
      cnpjBusca: map['cnpjBusca'] ?? '',
      email: map['email'] ?? '',
      emailBusca: map['emailBusca'] ?? '',
      emailVerificado: map['emailVerificado'] ?? false,
      fotoUrl: map['fotoUrl'] ?? '',
      endereco: map['endereco'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'nomeBusca': nomeBusca,
      'cnpj': cnpj,
      'cnpjBusca': cnpjBusca,
      'email': email,
      'emailBusca': emailBusca,
      'emailVerificado': emailVerificado,
      'fotoUrl': fotoUrl,
      'endereco': endereco,
    };
  }
}
