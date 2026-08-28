import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  final String uid;
  final String nome;
  final String nomeBusca;
  final String email;
  final String tipoUsuario; // '', 'estudante', 'proprietario', 'corretor'
  final String subtipoCorretor; // '', 'autonomo', 'empresa'
  final String fotoUrl;
  final bool perfilCompleto;
  final DateTime? ultimoAcesso;

  final String genero;

  final String cidade;
  final String cpf;
  final String cnpj;
  final String dataNascimento; // dd/MM/aaaa
  final String endereco;

  // preenchido so quando estudante menor de 18
  final String responsavelNome;
  final String responsavelEndereco;
  final String responsavelCpf;
  final String responsavelEmail;
  final bool responsavelEmailVerificado;

  // preenchido so quando corretor de empresa
  final String nomeEmpresa;
  final String cnpjEmpresa;
  final String enderecoEmpresa;
  final String emailEmpresa;
  final bool emailEmpresaVerificado;

  // vinculo com a imobiliaria (so corretor de empresa)
  final String imobiliariaId;
  final bool vinculoConfirmado;

  Usuario({
    required this.uid,
    required this.nome,
    this.nomeBusca = '',
    required this.email,
    this.tipoUsuario = '',
    this.subtipoCorretor = '',
    this.fotoUrl = '',
    this.perfilCompleto = false,
    this.ultimoAcesso,
    this.genero = '',
    this.cidade = '',
    this.cpf = '',
    this.cnpj = '',
    this.dataNascimento = '',
    this.endereco = '',
    this.responsavelNome = '',
    this.responsavelEndereco = '',
    this.responsavelCpf = '',
    this.responsavelEmail = '',
    this.responsavelEmailVerificado = false,
    this.nomeEmpresa = '',
    this.cnpjEmpresa = '',
    this.enderecoEmpresa = '',
    this.emailEmpresa = '',
    this.emailEmpresaVerificado = false,
    this.imobiliariaId = '',
    this.vinculoConfirmado = false,
  });

  factory Usuario.fromMap(Map<String, dynamic> map, String uid) {
    return Usuario(
      uid: uid,
      nome: map['nome'] ?? '',
      nomeBusca: map['nomeBusca'] ?? '',
      email: map['email'] ?? '',
      tipoUsuario: map['tipoUsuario'] ?? '',
      subtipoCorretor: map['subtipoCorretor'] ?? '',
      fotoUrl: map['fotoUrl'] ?? '',
      perfilCompleto: map['perfilCompleto'] ?? false,
      ultimoAcesso: (map['ultimoAcesso'] as Timestamp?)?.toDate(),
      genero: map['genero'] ?? '',
      cidade: map['cidade'] ?? '',
      cpf: map['cpf'] ?? '',
      cnpj: map['cnpj'] ?? '',
      dataNascimento: map['dataNascimento'] ?? '',
      endereco: map['endereco'] ?? '',
      responsavelNome: map['responsavelNome'] ?? '',
      responsavelEndereco: map['responsavelEndereco'] ?? '',
      responsavelCpf: map['responsavelCpf'] ?? '',
      responsavelEmail: map['responsavelEmail'] ?? '',
      responsavelEmailVerificado: map['responsavelEmailVerificado'] ?? false,
      nomeEmpresa: map['nomeEmpresa'] ?? '',
      cnpjEmpresa: map['cnpjEmpresa'] ?? '',
      enderecoEmpresa: map['enderecoEmpresa'] ?? '',
      emailEmpresa: map['emailEmpresa'] ?? '',
      emailEmpresaVerificado: map['emailEmpresaVerificado'] ?? false,
      imobiliariaId: map['imobiliariaId'] ?? '',
      vinculoConfirmado: map['vinculoConfirmado'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'nomeBusca': nomeBusca,
      'email': email,
      'tipoUsuario': tipoUsuario,
      'subtipoCorretor': subtipoCorretor,
      'fotoUrl': fotoUrl,
      'perfilCompleto': perfilCompleto,
      if (ultimoAcesso != null) 'ultimoAcesso': Timestamp.fromDate(ultimoAcesso!),
      'genero': genero,
      'cidade': cidade,
      'cpf': cpf,
      'cnpj': cnpj,
      'dataNascimento': dataNascimento,
      'endereco': endereco,
      'responsavelNome': responsavelNome,
      'responsavelEndereco': responsavelEndereco,
      'responsavelCpf': responsavelCpf,
      'responsavelEmail': responsavelEmail,
      'responsavelEmailVerificado': responsavelEmailVerificado,
      'nomeEmpresa': nomeEmpresa,
      'cnpjEmpresa': cnpjEmpresa,
      'enderecoEmpresa': enderecoEmpresa,
      'emailEmpresa': emailEmpresa,
      'emailEmpresaVerificado': emailEmpresaVerificado,
      'imobiliariaId': imobiliariaId,
      'vinculoConfirmado': vinculoConfirmado,
    };
  }
}
