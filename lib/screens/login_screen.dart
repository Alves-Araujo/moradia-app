import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/animated_gradient_button.dart';
import 'cadastro_screen.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _carregando = false;

  // animacoes de entrada
  late AnimationController _staggerController;
  late AnimationController _bgController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();

    // animacao de fundo (orbes)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // animacoes staggered pra 6 elementos
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnims = List.generate(6, (i) {
      final start = (i * 0.12).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _slideAnims = List.generate(6, (i) {
      final start = (i * 0.12).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    _staggerController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _staggerController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _entrar() {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || !email.contains('@')) {
      _mostrarErro('Informe um e-mail válido.');
      return;
    }
    if (senha.length < 6) {
      _mostrarErro('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() => _carregando = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim1, anim2) => const TelaPrincipal(tipoUsuario: 'estudante'),
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
        (route) => false,
      );
    });
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
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // fundo com gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [corFundoEscuro, const Color(0xFF12101F), const Color(0xFF0D0B18)]
                    : [corFundoClaro, const Color(0xFFF0EDFF), const Color(0xFFE8E4FF)],
              ),
            ),
          ),

          // orbes decorativos animados no fundo
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _OrbPainter(
                  progress: _bgController.value,
                  isDark: isDark,
                ),
              );
            },
          ),

          // conteudo principal
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: SizedBox(
                height: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 1),

                    // logo
                    _animarElemento(0, Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            width: 240,
                            height: 240,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    )),
                    const SizedBox(height: 12),

                    // subtitulo
                    _animarElemento(1, Column(
                      children: [
                        Text(
                          'O seu novo lar, focado nas suas prioridades.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    )),

                    const SizedBox(height: 40),

                    // campo email
                    _animarElemento(2, _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                    )),
                    const SizedBox(height: 16),

                    // campo senha
                    _animarElemento(3, _buildTextField(
                      controller: _senhaController,
                      label: 'Senha',
                      icon: Icons.lock_outline,
                      isDark: isDark,
                      obscureText: !_senhaVisivel,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    )),

                    // esqueceu a senha
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        ),
                        child: Text(
                          'Esqueceu a senha?',
                          style: TextStyle(
                            color: corPrimaria.withAlpha(200),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // botao entrar
                    _animarElemento(4, AnimatedGradientButton(
                      label: 'Entrar',
                      isLoading: _carregando,
                      onTap: _entrar,
                    )),
                    const SizedBox(height: 24),

                    // divisor "ou"
                    _animarElemento(5, Row(
                      children: [
                        Expanded(child: Divider(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade300)),
                      ],
                    )),
                    const SizedBox(height: 24),

                    // botao criar conta
                    _animarElemento(5, SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim1, anim2) => const TelaCadastro(),
                              transitionsBuilder: (context, anim1, anim2, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
                                  child: child,
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 350),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? Colors.white.withAlpha(25) : corPrimaria.withAlpha(60),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          backgroundColor: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(120),
                        ),
                        child: Text(
                          'Criar Conta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : corPrimaria,
                          ),
                        ),
                      ),
                    )),

                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.grey.shade500,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: corPrimaria.withAlpha(160), size: 22),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(40),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: corPrimaria, width: 1.5),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(180),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

// painter dos orbes decorativos do fundo da tela de login
class _OrbPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _OrbPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // orbe 1 - grande, canto superior direito
    final orb1X = size.width * 0.8 + sin(progress * 2 * pi) * 30;
    final orb1Y = size.height * 0.15 + cos(progress * 2 * pi) * 20;
    paint.shader = RadialGradient(
      colors: [
        corPrimaria.withAlpha(isDark ? 30 : 20),
        corPrimaria.withAlpha(0),
      ],
    ).createShader(Rect.fromCircle(center: Offset(orb1X, orb1Y), radius: 160));
    canvas.drawCircle(Offset(orb1X, orb1Y), 160, paint);

    // orbe 2 - medio, canto inferior esquerdo
    final orb2X = size.width * 0.2 + cos(progress * 2 * pi + 1) * 25;
    final orb2Y = size.height * 0.75 + sin(progress * 2 * pi + 1) * 30;
    paint.shader = RadialGradient(
      colors: [
        corPrimaria2.withAlpha(isDark ? 25 : 15),
        corPrimaria2.withAlpha(0),
      ],
    ).createShader(Rect.fromCircle(center: Offset(orb2X, orb2Y), radius: 130));
    canvas.drawCircle(Offset(orb2X, orb2Y), 130, paint);

    // orbe 3 - pequeno, centro da tela
    final orb3X = size.width * 0.5 + sin(progress * 2 * pi + 2) * 20;
    final orb3Y = size.height * 0.45 + cos(progress * 2 * pi + 2) * 15;
    paint.shader = RadialGradient(
      colors: [
        corDestaque.withAlpha(isDark ? 18 : 12),
        corDestaque.withAlpha(0),
      ],
    ).createShader(Rect.fromCircle(center: Offset(orb3X, orb3Y), radius: 90));
    canvas.drawCircle(Offset(orb3X, orb3Y), 90, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
