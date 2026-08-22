import 'package:flutter/material.dart';
import '../main.dart';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmaSenhaController = TextEditingController();

  String? _tipoUsuarioSelecionado;
  bool _senhaVisivel = false;
  bool _confirmaSenhaVisivel = false;
  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmaSenhaController.dispose();
    super.dispose();
  }

  void _cadastrar() {
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
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => TelaPrincipal(tipoUsuario: _tipoUsuarioSelecionado!),
        ),
        (Route<dynamic> route) => false,
      );
    });
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          // ✅ Cor adaptativa ao tema
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Criar Conta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preencha seus dados para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.grey),
              ),
              const SizedBox(height: 32),

              // Nome
              TextField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                ),
              ),
              const SizedBox(height: 16),

              // Tipo de usuário
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Eu sou um...',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                ),
                initialValue: _tipoUsuarioSelecionado,
                dropdownColor: isDark ? const Color(0xFF2C2C2E) : null,
                items: const [
                  DropdownMenuItem(value: 'estudante', child: Text('Estudante (Quero alugar)')),
                  DropdownMenuItem(value: 'proprietario', child: Text('Proprietário (Dono do imóvel)')),
                  DropdownMenuItem(value: 'corretor', child: Text('Corretor / Imobiliária')),
                ],
                onChanged: (String? novoValor) {
                  setState(() => _tipoUsuarioSelecionado = novoValor);
                },
              ),
              const SizedBox(height: 16),

              // Senha
              TextField(
                controller: _senhaController,
                obscureText: !_senhaVisivel,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                ),
              ),
              const SizedBox(height: 16),

              // Confirmar senha
              TextField(
                controller: _confirmaSenhaController,
                obscureText: !_confirmaSenhaVisivel,
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_confirmaSenhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _confirmaSenhaVisivel = !_confirmaSenhaVisivel),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                ),
              ),
              const SizedBox(height: 32),

              // Botão Cadastrar
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _carregando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Cadastrar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}