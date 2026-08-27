import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../main.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/busca_service.dart';
import '../services/imgbb_service.dart';
import '../services/usuario_service.dart';
import '../utils/documento_validator.dart';
import '../utils/moderacao.dart';
import '../widgets/animated_gradient_button.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/seletor_tipo_usuario.dart';

const List<String> generosDisponiveis = [
  'Masculino cis', 'Feminino cis', 'Masculino trans', 'Feminino trans',
  'Prefiro não dizer', 'Outro',
];

// tela cheia de "concluir perfil" -- onde o usuario escolhe o tipo de conta
// e preenche os documentos exigidos pra liberar o acesso completo ao app
class ConcluirPerfilScreen extends StatefulWidget {
  final Usuario perfil;
  const ConcluirPerfilScreen({super.key, required this.perfil});

  @override
  State<ConcluirPerfilScreen> createState() => _ConcluirPerfilScreenState();
}

class _ConcluirPerfilScreenState extends State<ConcluirPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nomeController;
  late TextEditingController _cidadeController; // fornecido pelo proprio Autocomplete
  final _enderecoController = TextEditingController();
  final _documentoController = TextEditingController();

  final _nomeEmpresaController = TextEditingController();
  final _cnpjEmpresaController = TextEditingController();
  final _enderecoEmpresaController = TextEditingController();
  final _emailEmpresaController = TextEditingController();

  final _respNomeController = TextEditingController();
  final _respEnderecoController = TextEditingController();
  final _respCpfController = TextEditingController();
  final _respEmailController = TextEditingController();

  final _telefoneController = TextEditingController();
  final _codigoOtpController = TextEditingController();

  final _mascaraCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {'#': RegExp(r'[0-9]')});
  final _mascaraCnpj = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {'#': RegExp(r'[0-9]')});
  final _mascaraCnpjEmpresa = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {'#': RegExp(r'[0-9]')});
  final _mascaraCpfResponsavel = MaskTextInputFormatter(mask: '###.###.###-##', filter: {'#': RegExp(r'[0-9]')});
  final _mascaraTelefone = MaskTextInputFormatter(mask: '(##) #####-####', filter: {'#': RegExp(r'[0-9]')});

  String? _tipoSelecionado;
  String _subtipoCorretor = '';
  String _generoSelecionado = '';
  bool _documentoEhCnpj = false;
  DateTime? _dataNascimento;
  String _fotoUrl = '';
  bool _enviandoFoto = false;
  bool _salvando = false;

  bool _telefoneVerificado = false;
  bool _enviandoCodigo = false;
  String? _verificationId;

  // proprietario e corretor autonomo podem escolher CPF ou CNPJ; corretor de
  // empresa tem o CNPJ na secao da empresa, entao o documento pessoal dele e sempre CPF
  bool get _permiteEscolherCnpj =>
      _tipoSelecionado == 'proprietario' ||
      (_tipoSelecionado == 'corretor' && _subtipoCorretor == 'autonomo');

  int? get _idade => _dataNascimento != null ? calcularIdade(_dataNascimento!) : null;

  bool get _mostraSecaoResponsavel =>
      _tipoSelecionado == 'estudante' && _idade != null && _idade! < 18;

  bool get _mostraSecaoEmpresa => _tipoSelecionado == 'corretor' && _subtipoCorretor == 'empresa';

  @override
  void initState() {
    super.initState();
    final p = widget.perfil;
    _nomeController = TextEditingController(text: p.nome);
    _enderecoController.text = p.endereco;
    _fotoUrl = p.fotoUrl;
    _tipoSelecionado = p.tipoUsuario.isNotEmpty ? p.tipoUsuario : null;
    _subtipoCorretor = p.subtipoCorretor;
    _generoSelecionado = p.genero;
    _telefoneController.text = p.telefone;
    _telefoneVerificado = p.telefoneVerificado;
    _documentoEhCnpj = p.cnpj.isNotEmpty;
    _documentoController.text = _documentoEhCnpj ? p.cnpj : p.cpf;
    if (p.dataNascimento.isNotEmpty) {
      final partes = p.dataNascimento.split('/');
      if (partes.length == 3) {
        _dataNascimento = DateTime.tryParse('${partes[2]}-${partes[1]}-${partes[0]}');
      }
    }
    _nomeEmpresaController.text = p.nomeEmpresa;
    _cnpjEmpresaController.text = p.cnpjEmpresa;
    _enderecoEmpresaController.text = p.enderecoEmpresa;
    _emailEmpresaController.text = p.emailEmpresa;
    _respNomeController.text = p.responsavelNome;
    _respEnderecoController.text = p.responsavelEndereco;
    _respCpfController.text = p.responsavelCpf;
    _respEmailController.text = p.responsavelEmail;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _enderecoController.dispose();
    _documentoController.dispose();
    _nomeEmpresaController.dispose();
    _cnpjEmpresaController.dispose();
    _enderecoEmpresaController.dispose();
    _emailEmpresaController.dispose();
    _respNomeController.dispose();
    _respEnderecoController.dispose();
    _respCpfController.dispose();
    _respEmailController.dispose();
    _telefoneController.dispose();
    _codigoOtpController.dispose();
    super.dispose();
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: corErro),
    );
  }

  // numero digitado e so DDD+numero -- prefixa +55 (Brasil) pro Firebase Phone Auth
  String get _telefoneE164 {
    final digitos = _telefoneController.text.replaceAll(RegExp(r'\D'), '');
    return '+55$digitos';
  }

  Future<void> _enviarCodigoVerificacao() async {
    final digitos = _telefoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length < 10) {
      _mostrarErro('Informe um telefone válido (com DDD).');
      return;
    }

    setState(() => _enviandoCodigo = true);
    try {
      await AuthService.instance.verificarTelefone(
        numeroCompleto: _telefoneE164,
        aoCodigoEnviado: (verificationId) {
          _verificationId = verificationId;
          if (mounted) {
            setState(() => _enviandoCodigo = false);
            _mostrarFolhaCodigoOtp();
          }
        },
        aoFalhar: (erro) {
          if (mounted) {
            setState(() => _enviandoCodigo = false);
            _mostrarErro(erro);
          }
        },
        aoVerificarAutomaticamente: () {
          if (mounted) {
            setState(() {
              _telefoneVerificado = true;
              _enviandoCodigo = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoCodigo = false);
        _mostrarErro('Erro ao enviar código: $e');
      }
    }
  }

  void _mostrarFolhaCodigoOtp() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _codigoOtpController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? corCardEscuro : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            bool confirmando = false;
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Digite o código enviado por SMS',
                    style: AppTextStyles.heading3.copyWith(color: isDark ? Colors.white : Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _telefoneE164,
                    style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codigoOtpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 22, letterSpacing: 8),
                    decoration: InputDecoration(
                      hintText: '000000',
                      filled: true,
                      fillColor: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedGradientButton(
                    label: 'Confirmar',
                    isLoading: confirmando,
                    onTap: () async {
                      final codigo = _codigoOtpController.text.trim();
                      if (codigo.isEmpty || _verificationId == null) return;
                      setSheetState(() => confirmando = true);
                      try {
                        await AuthService.instance.confirmarCodigoTelefone(_verificationId!, codigo);
                        if (mounted) setState(() => _telefoneVerificado = true);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      } catch (e) {
                        setSheetState(() => confirmando = false);
                        if (mounted) _mostrarErro('Código inválido ou expirado.');
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _trocarFoto() async {
    final imagem = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (imagem == null) return;
    setState(() => _enviandoFoto = true);
    try {
      final url = await ImgbbService.instance.enviarImagem(imagem);
      if (mounted) setState(() => _fotoUrl = url);
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao enviar foto: $e');
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  Future<void> _escolherDataNascimento() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(hoje.year - 20, hoje.month, hoje.day),
      firstDate: DateTime(hoje.year - 100),
      lastDate: hoje,
      helpText: 'Data de nascimento',
    );
    if (escolhida != null) setState(() => _dataNascimento = escolhida);
  }

  String _dataFormatada(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  // valida os campos que nao tem TextFormField.validator (documento, data,
  // secoes condicionais) -- retorna a primeira mensagem de erro encontrada
  String? _validarCamposCondicionais() {
    if (_tipoSelecionado == null) return 'Selecione o tipo de conta.';

    if (_generoSelecionado.isEmpty) return 'Selecione seu gênero.';

    if (!_telefoneVerificado) return 'Verifique seu número de telefone por SMS.';

    if (_dataNascimento == null) return 'Informe a data de nascimento.';

    final documento = _documentoController.text.trim();
    if (documento.isEmpty) return 'Informe o CPF${_permiteEscolherCnpj ? ' ou CNPJ' : ''}.';
    if (_documentoEhCnpj) {
      if (!validarCNPJ(documento)) return 'CNPJ inválido.';
    } else {
      if (!validarCPF(documento)) return 'CPF inválido.';
    }

    if (_mostraSecaoEmpresa) {
      if (_nomeEmpresaController.text.trim().isEmpty) return 'Informe o nome da empresa.';
      if (!validarCNPJ(_cnpjEmpresaController.text.trim())) return 'CNPJ da empresa inválido.';
      if (_enderecoEmpresaController.text.trim().isEmpty) return 'Informe o endereço corporativo.';
      if (!_emailEmpresaController.text.trim().contains('@')) return 'Informe um e-mail válido da empresa.';
    }

    if (_tipoSelecionado == 'corretor' && _subtipoCorretor.isEmpty) {
      return 'Selecione se você é corretor autônomo ou de empresa.';
    }

    if (_mostraSecaoResponsavel) {
      if (_respNomeController.text.trim().isEmpty) return 'Informe o nome do responsável.';
      if (_respEnderecoController.text.trim().isEmpty) return 'Informe o endereço do responsável.';
      if (!validarCPF(_respCpfController.text.trim())) return 'CPF do responsável inválido.';
      if (!_respEmailController.text.trim().contains('@')) return 'Informe um e-mail válido do responsável.';
    }

    return null;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final nome = _nomeController.text.trim();
    if (!temNomeESobrenome(nome)) {
      _mostrarErro('Informe nome e sobrenome.');
      return;
    }
    if (contemPalavraImpropria(nome)) {
      _mostrarErro('Esse nome contém palavras não permitidas.');
      return;
    }

    final erroCondicional = _validarCamposCondicionais();
    if (erroCondicional != null) {
      _mostrarErro(erroCondicional);
      return;
    }

    setState(() => _salvando = true);
    try {
      if (await UsuarioService.instance.nomeJaExiste(nome, ignorarUid: widget.perfil.uid)) {
        _mostrarErro('Já existe uma conta cadastrada com esse nome.');
        return;
      }

      final documento = _documentoController.text.trim();

      final atualizado = Usuario(
        uid: widget.perfil.uid,
        nome: nome,
        nomeBusca: normalizarNome(nome),
        email: widget.perfil.email,
        tipoUsuario: _tipoSelecionado!,
        subtipoCorretor: _tipoSelecionado == 'corretor' ? _subtipoCorretor : '',
        fotoUrl: _fotoUrl,
        perfilCompleto: true,
        genero: _generoSelecionado,
        telefone: _telefoneController.text.trim(),
        telefoneVerificado: _telefoneVerificado,
        cidade: _cidadeController.text.trim(),
        cpf: _documentoEhCnpj ? '' : documento,
        cnpj: _documentoEhCnpj ? documento : '',
        dataNascimento: _dataFormatada(_dataNascimento!),
        endereco: _enderecoController.text.trim(),
        responsavelNome: _mostraSecaoResponsavel ? _respNomeController.text.trim() : '',
        responsavelEndereco: _mostraSecaoResponsavel ? _respEnderecoController.text.trim() : '',
        responsavelCpf: _mostraSecaoResponsavel ? _respCpfController.text.trim() : '',
        responsavelEmail: _mostraSecaoResponsavel ? _respEmailController.text.trim() : '',
        responsavelEmailVerificado: false,
        nomeEmpresa: _mostraSecaoEmpresa ? _nomeEmpresaController.text.trim() : '',
        cnpjEmpresa: _mostraSecaoEmpresa ? _cnpjEmpresaController.text.trim() : '',
        enderecoEmpresa: _mostraSecaoEmpresa ? _enderecoEmpresaController.text.trim() : '',
        emailEmpresa: _mostraSecaoEmpresa ? _emailEmpresaController.text.trim() : '',
        emailEmpresaVerificado: false,
      );

      await UsuarioService.instance.completarPerfil(atualizado);

      if (mounted) Navigator.pop(context, atualizado);
    } catch (e) {
      _mostrarErro('Erro ao salvar perfil: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? corFundoEscuro : const Color(0xFFF6F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          widget.perfil.perfilCompleto ? 'Editar Perfil' : 'Concluir Perfil',
          style: AppTextStyles.heading3.copyWith(color: isDark ? Colors.white : Colors.black87),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Center(
              child: Stack(
                children: [
                  AvatarWidget(nome: _nomeController.text, fotoUrl: _fotoUrl, size: 96, showOnlineIndicator: false),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _enviandoFoto ? null : _trocarFoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: gradientePrincipal,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? corFundoEscuro : Colors.white, width: 3),
                        ),
                        child: _enviandoFoto
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _secao(
              isDark: isDark,
              titulo: 'Dados básicos',
              icone: Icons.person_rounded,
              filhos: [
                _campo(controller: _nomeController, label: 'Nome completo', icon: Icons.badge_outlined, isDark: isDark,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 14),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: widget.perfil.cidade),
                  optionsBuilder: (value) {
                    if (value.text.isEmpty) return const Iterable<String>.empty();
                    final termo = normalizarNome(value.text);
                    return locaisConhecidosParaCidade.where((c) => normalizarNome(c).contains(termo));
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    _cidadeController = controller;
                    return _campo(
                      controller: controller,
                      focusNode: focusNode,
                      label: 'Cidade / Região',
                      icon: Icons.location_city_rounded,
                      isDark: isDark,
                    );
                  },
                ),
                const SizedBox(height: 14),
                _campo(controller: _enderecoController, label: 'Endereço atual', icon: Icons.home_outlined, isDark: isDark,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu endereço' : null),
                const SizedBox(height: 14),
                _campoData(isDark),
              ],
            ),
            const SizedBox(height: 20),

            _secao(
              isDark: isDark,
              titulo: 'Gênero',
              icone: Icons.diversity_1_outlined,
              filhos: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: generosDisponiveis.map((genero) {
                    final selecionado = _generoSelecionado == genero;
                    return GestureDetector(
                      onTap: () => setState(() => _generoSelecionado = genero),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: selecionado ? gradientePrincipal : null,
                          color: selecionado ? null : (isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          genero,
                          style: TextStyle(
                            color: selecionado ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _secao(
              isDark: isDark,
              titulo: 'Telefone',
              icone: Icons.smartphone_rounded,
              filhos: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _campo(
                        controller: _telefoneController,
                        label: 'Telefone com DDD',
                        icon: Icons.phone_outlined,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                        formatters: [_mascaraTelefone],
                        onChanged: (_) {
                          if (_telefoneVerificado) setState(() => _telefoneVerificado = false);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_telefoneVerificado || _enviandoCodigo) ? null : _enviarCodigoVerificacao,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _telefoneVerificado ? corSucesso : corPrimaria,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _enviandoCodigo
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(_telefoneVerificado ? Icons.check_rounded : Icons.sms_outlined),
                      ),
                    ),
                  ],
                ),
                if (_telefoneVerificado) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: corSucesso),
                      const SizedBox(width: 4),
                      Text('Telefone verificado', style: AppTextStyles.caption.copyWith(color: corSucesso)),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            _secao(
              isDark: isDark,
              titulo: 'Tipo de conta',
              icone: Icons.workspace_premium_outlined,
              filhos: [
                SeletorTipoUsuario(
                  valorSelecionado: _tipoSelecionado,
                  isDark: isDark,
                  onSelecionar: (valor) => setState(() {
                    _tipoSelecionado = valor;
                    if (valor != 'corretor') _subtipoCorretor = '';
                    _documentoEhCnpj = false;
                    _documentoController.clear();
                  }),
                ),
                if (_tipoSelecionado == 'corretor') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _chipEscolha(
                          isDark: isDark,
                          selecionado: _subtipoCorretor == 'autonomo',
                          label: 'Autônomo',
                          onTap: () => setState(() => _subtipoCorretor = 'autonomo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _chipEscolha(
                          isDark: isDark,
                          selecionado: _subtipoCorretor == 'empresa',
                          label: 'Empresa',
                          onTap: () => setState(() {
                            _subtipoCorretor = 'empresa';
                            _documentoEhCnpj = false;
                            _documentoController.clear();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            if (_tipoSelecionado != null)
              _secao(
                isDark: isDark,
                titulo: 'Documento pessoal',
                icone: Icons.badge_outlined,
                filhos: [
                  if (_permiteEscolherCnpj)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: _chipEscolha(
                              isDark: isDark,
                              selecionado: !_documentoEhCnpj,
                              label: 'Pessoa Física (CPF)',
                              onTap: () => setState(() {
                                _documentoEhCnpj = false;
                                _documentoController.clear();
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _chipEscolha(
                              isDark: isDark,
                              selecionado: _documentoEhCnpj,
                              label: 'Pessoa Jurídica (CNPJ)',
                              onTap: () => setState(() {
                                _documentoEhCnpj = true;
                                _documentoController.clear();
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _campo(
                    controller: _documentoController,
                    label: _documentoEhCnpj ? 'CNPJ' : 'CPF',
                    icon: Icons.badge_outlined,
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                    formatters: [_documentoEhCnpj ? _mascaraCnpj : _mascaraCpf],
                  ),
                ],
              ),

            if (_mostraSecaoEmpresa) ...[
              const SizedBox(height: 20),
              _secao(
                isDark: isDark,
                titulo: 'Dados da empresa',
                icone: Icons.apartment_rounded,
                filhos: [
                  _campo(controller: _nomeEmpresaController, label: 'Nome da empresa', icon: Icons.store_outlined, isDark: isDark),
                  const SizedBox(height: 14),
                  _campo(controller: _cnpjEmpresaController, label: 'CNPJ da empresa', icon: Icons.badge_outlined, isDark: isDark,
                      keyboardType: TextInputType.number, formatters: [_mascaraCnpjEmpresa]),
                  const SizedBox(height: 14),
                  _campo(controller: _enderecoEmpresaController, label: 'Endereço corporativo', icon: Icons.location_on_outlined, isDark: isDark),
                  const SizedBox(height: 14),
                  _campo(controller: _emailEmpresaController, label: 'E-mail da empresa', icon: Icons.email_outlined, isDark: isDark,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 8),
                  Text(
                    'Vamos enviar um e-mail de confirmação pra esse endereço assim que a verificação estiver disponível. Por enquanto ele fica salvo como pendente.',
                    style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                  ),
                ],
              ),
            ],

            if (_mostraSecaoResponsavel) ...[
              const SizedBox(height: 20),
              _secao(
                isDark: isDark,
                titulo: 'Dados do responsável (menor de 18 anos)',
                icone: Icons.family_restroom_rounded,
                filhos: [
                  _campo(controller: _respNomeController, label: 'Nome do responsável', icon: Icons.person_outline, isDark: isDark),
                  const SizedBox(height: 14),
                  _campo(controller: _respEnderecoController, label: 'Endereço do responsável', icon: Icons.home_outlined, isDark: isDark),
                  const SizedBox(height: 14),
                  _campo(controller: _respCpfController, label: 'CPF do responsável', icon: Icons.badge_outlined, isDark: isDark,
                      keyboardType: TextInputType.number, formatters: [_mascaraCpfResponsavel]),
                  const SizedBox(height: 14),
                  _campo(controller: _respEmailController, label: 'E-mail do responsável', icon: Icons.email_outlined, isDark: isDark,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 8),
                  Text(
                    'Vamos enviar uma confirmação pro e-mail do responsável assim que a verificação estiver disponível. Por enquanto fica salvo como pendente.',
                    style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
            AnimatedGradientButton(
              label: 'Salvar perfil',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _salvando,
              onTap: _salvar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoData(bool isDark) {
    final temData = _dataNascimento != null;
    return InkWell(
      onTap: _escolherDataNascimento,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: isDark ? Colors.white54 : corPrimaria),
            const SizedBox(width: 12),
            Text(
              temData
                  ? '${_dataFormatada(_dataNascimento!)}  •  $_idade anos'
                  : 'Data de nascimento',
              style: TextStyle(
                color: temData
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secao({
    required bool isDark,
    required String titulo,
    required IconData icone,
    required List<Widget> filhos,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? corCardEscuro : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(isDark ? 40 : 8), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: gradientePrincipal, borderRadius: BorderRadius.circular(10)),
                child: Icon(icone, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(titulo, style: AppTextStyles.bodyBold.copyWith(color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          ...filhos,
        ],
      ),
    );
  }

  Widget _chipEscolha({
    required bool isDark,
    required bool selecionado,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selecionado ? gradientePrincipal : null,
          color: selecionado ? null : (isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600),
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : corPrimaria),
        filled: true,
        fillColor: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
