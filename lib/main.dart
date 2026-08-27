import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// imports do firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models/usuario.dart';
import 'screens/auth_gate.dart';
import 'screens/map_screen.dart';
import 'screens/resumo_screen.dart';
import 'screens/chat_list_screen.dart';

// controle do tema do app inteiro
final ValueNotifier<ThemeMode> temaGlobal = ValueNotifier(ThemeMode.system);

// posicao do inatel, usada como centro padrao do mapa e destino da rota
const LatLng posicaoInatel = LatLng(-22.2528, -45.6976);

// mesma chave que ja esta no AndroidManifest.xml, usada aqui pra chamar a Directions API
const String googleMapsApiKey = 'AIzaSyCDSwKb86bQTu7rwcwzW0r1oRZY9U-RNrQ';

// credenciais do ZegoCloud (chamadas de voz/video no chat) -- crie uma conta
// gratis em zegocloud.com e cole o AppID/AppSign do seu projeto aqui
const int zegoAppId = 0;
const String zegoAppSign = 'COLOQUE_AQUI_O_APPSIGN_DO_ZEGOCLOUD';

// cores principais
const corPrimaria = Color(0xFF00509E);
const corPrimaria2 = Color(0xFF007BFF);
const corDestaque = Color(0xFF00C6FF);
const corFundoClaro = Color(0xFFFAFAFE);
const corFundoEscuro = Color(0xFF0A0A10);
const corCardEscuro = Color(0xFF16161F);
const corSuperficieEscura = Color(0xFF1E1E2A);

// cores pra feedback (sucesso, aviso, erro)
const corSucesso = Color(0xFF10B981);
const corAtencao = Color(0xFFF59E0B);
const corErro = Color(0xFFEF4444);

// gradientes usados nos botoes e cards
const gradientePrincipal = LinearGradient(
  colors: [corPrimaria, corPrimaria2, Color(0xFF00B4DB)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const gradienteSecundario = LinearGradient(
  colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const gradienteEvento = LinearGradient(
  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// estilos de texto padronizados pra manter consistencia
class AppTextStyles {
  static const heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.2,
  );

  static const heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.3,
  );

  static const heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  static const bodyBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const captionBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.3,
  );
}

// inicializa o firebase antes de rodar o app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MeuAppEstudantil());
}

class MeuAppEstudantil extends StatelessWidget {
  const MeuAppEstudantil({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaGlobal,
      builder: (context, currentMode, _) {
        // ajustar status bar conforme o tema
        final isDark = currentMode == ThemeMode.dark ||
            (currentMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: isDark ? corCardEscuro : Colors.white,
        ));

        return MaterialApp(
          title: 'Hive Moradias',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorSchemeSeed: corPrimaria,
            useMaterial3: true,
            scaffoldBackgroundColor: corFundoClaro,
            textTheme: GoogleFonts.interTextTheme(),
            splashColor: corPrimaria.withAlpha(20),
            highlightColor: corPrimaria.withAlpha(10),
            dividerTheme: DividerThemeData(
              color: Colors.grey.withAlpha(25),
              thickness: 1,
            ),
            chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.transparent),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: corPrimaria,
            useMaterial3: true,
            scaffoldBackgroundColor: corFundoEscuro,
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            splashColor: corPrimaria.withAlpha(25),
            highlightColor: corPrimaria.withAlpha(15),
            dividerTheme: DividerThemeData(
              color: Colors.white.withAlpha(12),
              thickness: 1,
            ),
            chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.transparent),
              ),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  final Usuario perfil;
  const TelaPrincipal({super.key, required this.perfil});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal>
    with SingleTickerProviderStateMixin {
  int _indiceAtual = 0;
  late final List<Widget> _telas;
  late AnimationController _navAnimController;

  @override
  void initState() {
    super.initState();
    _telas = [
      CentroDoMapa(perfil: widget.perfil),
      TelaResumo(perfil: widget.perfil),
      const TelaListaChats(),
    ];
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _navAnimController.forward();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: IndexedStack(
          key: ValueKey(_indiceAtual),
          index: _indiceAtual,
          children: _telas,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? corCardEscuro : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(6),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 8),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.map_outlined, Icons.map_rounded, 'Mapa', isDark),
                _buildNavItem(1, Icons.home_outlined, Icons.home_rounded, 'Resumo', isDark),
                _buildNavItem(2, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat', isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, bool isDark) {
    final bool isSelected = _indiceAtual == index;

    return GestureDetector(
      onTap: () => setState(() => _indiceAtual = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? corPrimaria.withAlpha(18) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? corPrimaria : (isDark ? Colors.white54 : Colors.grey),
                size: 24,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: corPrimaria,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}