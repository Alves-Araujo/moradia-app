import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../widgets/animated_gradient_button.dart';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmaSenhaController = TextEditingController();

  String? _tipoUsuarioSelecionado;
  bool _senhaVisivel = false;
  bool _confirmaSenhaVisivel = false;
  bool _carregando = false;

  late AnimationController _animController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  // tipos de usuario disponiveis
  final _tiposUsuario = [
    {'value': 'estudante', 'label': 'Estudante', 'desc': 'Quero alugar', 'icon': Icons.school_rounded},
    {'value': 'proprietario', 'label': 'Proprietário', 'desc': 'Dono do imóvel', 'icon': Icons.home_work_rounded},
    {'value': 'corretor', 'label': 'Corretor', 'desc': 'Imobiliária', 'icon': Icons.business_center_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnims = List.generate(8, (i) {
      final start = (i * 0.1).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Interval(start, end, curve: Curves.easeOut)),
      );
    });

    _slideAnims = List.generate(8, (i) {
      final start = (i * 0.1).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
        CurvedAnimation(parent: _animController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      );
    });

    _animController.forward();

    // atualiza a barra de forca da senha quando digita
    _senhaController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmaSenhaController.dispose();
    _animController.dispose();
    super.dispose();
  }

  double get _forcaSenha {
    final senha = _senhaController.text;
    if (senha.isEmpty) return 0;
    double forca = 0;
    if (senha.length >= 6) forca += 0.25;
    if (senha.length >= 10) forca += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(senha)) forca += 0.2;
    if (RegExp(r'[0-9]').hasMatch(senha)) forca += 0.2;
    if (RegExp(r'[!@#\$%\^\&\*\(\)_\+\-=]').hasMatch(senha)) forca += 0.2;
    return forca.clamp(0.0, 1.0);
  }

  Color get _corForcaSenha {
    if (_forcaSenha < 0.3) return corErro;
    if (_forcaSenha < 0.6) return corAtencao;
    return corSucesso;
  }

  String get _textoForcaSenha {
    if (_senhaController.text.isEmpty) return '';
    if (_forcaSenha < 0.3) return 'Fraca';
    if (_forcaSenha < 0.6) return 'Média';
    if (_forcaSenha < 0.85) return 'Forte';
    return 'Muito forte';
  }

  // Funcao assincrona para realizar cadastro no Firebase Auth e salvar no Firestore
  Future<void> _cadastrar() async {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final confirmaSenha = _confirmaSenhaController.text;

    if (nome.isEmpty) {
      _mostrarErro('Informe seu nome completo.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _mostrarErro('Informe um e-mail válido.');
      return;
    }
    if (_tipoUsuarioSelecionado == null) {
      _mostrarErro('Selecione seu tipo de perfil.');
      return;
    }
    if (senha.length < 6) {
      _mostrarErro('A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (senha != confirmaSenha) {
      _mostrarErro('As senhas não coincidem.');
      return;
    }

    setState(() => _carregando = true);

    try {
      // 1. Cria a conta no Authentication
      final credencial = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      // 2. Salva os dados complementares no Firestore usando o UID gerado
      if (credencial.user != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(credencial.user!.uid).set({
          'nome': nome,
          'email': email,
          'tipoUsuario': _tipoUsuarioSelecionado,
          'dataCriacao': FieldValue.serverTimestamp(), // Pega a hora exata do servidor
        });
      }

      if (!mounted) return;

      // 3. Se deu tudo certo, vai para a tela principal
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim1, anim2) => TelaPrincipal(tipoUsuario: _tipoUsuarioSelecionado!),
          transitionsBuilder: (context, anim1, anim2, child) {
            return FadeTransition(
              opacity: anim1,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
            (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      // Captura erros de cadastro do Firebase
      String msgErro = 'Erro ao criar conta.';
      if (e.code == 'weak-password') {
        msgErro = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        msgErro = 'Já existe uma conta cadastrada com este e-mail.';
      } else if (e.code == 'invalid-email') {
        msgErro = 'O formato do e-mail é inválido.';
      }
      _mostrarErro(msgErro);
    } catch (e) {
      _mostrarErro('Ocorreu um erro inesperado.');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: corErro,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _animarElemento(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(position: _slideAnims[index], child: child),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.grey.shade500,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: corPrimaria.withAlpha(160), size: 22),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(40)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: corPrimaria, width: 1.5),
      ),
      filled: true,
      fillColor: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(180),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [corFundoEscuro, const Color(0xFF12101F), const Color(0xFF0D0B18)]
                : [corFundoClaro, const Color(0xFFF0EDFF), const Color(0xFFE8E4FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // botao de voltar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 18,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // formulario
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      _animarElemento(0, Column(
                        children: [
                          Text(
                            'Criar Conta',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.heading1.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Preencha seus dados para começar.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )),
                      const SizedBox(height: 24),

                      // foto de perfil
                      _animarElemento(1, Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_outline, size: 40, color: isDark ? Colors.white38 : Colors.grey),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Abrindo câmera/galeria...')),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: corPrimaria,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF12101F) : const Color(0xFFF0EDFF),
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 32),

                      // campo nome
                      _animarElemento(2, TextField(
                        controller: _nomeController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: _inputDeco('Nome completo', Icons.person_outline, isDark),
                      )),
                      const SizedBox(height: 16),

                      // campo email
                      _animarElemento(3, TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: _inputDeco('Email', Icons.email_outlined, isDark),
                      )),
                      const SizedBox(height: 20),

                      // tipo de usuario
                      _animarElemento(4, Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eu sou um...',
                            style: AppTextStyles.captionBold.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: _tiposUsuario.map((tipo) {
                              final bool selected = _tipoUsuarioSelecionado == tipo['value'];
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _tipoUsuarioSelecionado = tipo['value'] as String),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    margin: EdgeInsets.only(
                                      right: tipo != _tiposUsuario.last ? 10 : 0,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? corPrimaria.withAlpha(isDark ? 30 : 20)
                                          : (isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(180)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: selected
                                            ? corPrimaria
                                            : (isDark ? Colors.white.withAlpha(12) : Colors.grey.withAlpha(30)),
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? corPrimaria.withAlpha(30)
                                                : (isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            tipo['icon'] as IconData,
                                            color: selected ? corPrimaria : (isDark ? Colors.white54 : Colors.grey),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          tipo['label'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? corPrimaria
                                                : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tipo['desc'] as String,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? Colors.white38 : Colors.grey,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      )),
                      const SizedBox(height: 20),

                      // campo senha
                      _animarElemento(5, Column(
                        children: [
                          TextField(
                            controller: _senhaController,
                            obscureText: !_senhaVisivel,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: _inputDeco('Senha', Icons.lock_outline, isDark).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: isDark ? Colors.white38 : Colors.grey,
                                ),
                                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                              ),
                            ),
                          ),
                          // barra de forca da senha
                          if (_senhaController.text.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _forcaSenha,
                                      minHeight: 4,
                                      backgroundColor: isDark ? Colors.white.withAlpha(12) : Colors.grey.withAlpha(30),
                                      valueColor: AlwaysStoppedAnimation(_corForcaSenha),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _textoForcaSenha,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _corForcaSenha,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      )),
                      const SizedBox(height: 16),

                      // confirmar senha
                      _animarElemento(6, TextField(
                        controller: _confirmaSenhaController,
                        obscureText: !_confirmaSenhaVisivel,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: _inputDeco('Confirmar senha', Icons.lock_outline, isDark).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmaSenhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            onPressed: () => setState(() => _confirmaSenhaVisivel = !_confirmaSenhaVisivel),
                          ),
                        ),
                      )),
                      const SizedBox(height: 32),

                      // botao cadastrar
                      _animarElemento(7, AnimatedGradientButton(
                        label: 'Cadastrar',
                        isLoading: _carregando,
                        onTap: _cadastrar,
                      )),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}