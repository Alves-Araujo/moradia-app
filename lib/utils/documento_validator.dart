// validacao pelo digito verificador oficial -- confirma que o numero é
// matematicamente valido, nao que a pessoa é realmente dona dele (isso exigiria
// consulta paga a um servico tipo Serpro/ReceitaWS, fora do escopo aqui)

bool validarCPF(String cpf) {
  final digitos = cpf.replaceAll(RegExp(r'\D'), '');
  if (digitos.length != 11) return false;
  if (RegExp(r'^(\d)\1*$').hasMatch(digitos)) return false;

  int soma = 0;
  for (var i = 0; i < 9; i++) {
    soma += int.parse(digitos[i]) * (10 - i);
  }
  int resto = soma % 11;
  final dv1 = resto < 2 ? 0 : 11 - resto;
  if (dv1 != int.parse(digitos[9])) return false;

  soma = 0;
  for (var i = 0; i < 10; i++) {
    soma += int.parse(digitos[i]) * (11 - i);
  }
  resto = soma % 11;
  final dv2 = resto < 2 ? 0 : 11 - resto;
  if (dv2 != int.parse(digitos[10])) return false;

  return true;
}

bool validarCNPJ(String cnpj) {
  final digitos = cnpj.replaceAll(RegExp(r'\D'), '');
  if (digitos.length != 14) return false;
  if (RegExp(r'^(\d)\1*$').hasMatch(digitos)) return false;

  const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  int soma = 0;
  for (var i = 0; i < 12; i++) {
    soma += int.parse(digitos[i]) * pesos1[i];
  }
  int resto = soma % 11;
  final dv1 = resto < 2 ? 0 : 11 - resto;
  if (dv1 != int.parse(digitos[12])) return false;

  const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  soma = 0;
  for (var i = 0; i < 13; i++) {
    soma += int.parse(digitos[i]) * pesos2[i];
  }
  resto = soma % 11;
  final dv2 = resto < 2 ? 0 : 11 - resto;
  if (dv2 != int.parse(digitos[13])) return false;

  return true;
}

int calcularIdade(DateTime nascimento, {DateTime? hoje}) {
  final agora = hoje ?? DateTime.now();
  int idade = agora.year - nascimento.year;
  final aniversarioJaPassouEsseAno = agora.month > nascimento.month ||
      (agora.month == nascimento.month && agora.day >= nascimento.day);
  if (!aniversarioJaPassouEsseAno) idade--;
  return idade;
}
