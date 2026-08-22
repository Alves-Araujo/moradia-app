import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/resumo_screen.dart';
import 'screens/chat_list_screen.dart';

/// Notificador global de tema — usado pelas telas para alternar light/dark.
final ValueNotifier<ThemeMode> temaGlobal = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const MeuAppEstudantil());
}

class MeuAppEstudantil extends StatelessWidget {
  const MeuAppEstudantil({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaGlobal,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Hive Moradias',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorSchemeSeed: Colors.blueAccent,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.blueAccent,
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
            fontFamily: 'Roboto',
          ),
          home: const TelaLogin(),
        );
      },
    );
  }
}

/// Tela principal com navegação por abas (Mapa, Resumo, Chat).
class TelaPrincipal extends StatefulWidget {
  final String tipoUsuario;
  const TelaPrincipal({super.key, required this.tipoUsuario});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _indiceAtual = 0;

  late final List<Widget> _telas;

  @override
  void initState() {
    super.initState();
    _telas = [
      CentroDoMapa(tipoUsuario: widget.tipoUsuario),
      TelaResumo(tipoUsuario: widget.tipoUsuario),
      const TelaListaChats(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _indiceAtual,
        children: _telas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (i) => setState(() => _indiceAtual = i),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        indicatorColor: Colors.blueAccent.withAlpha(38),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: Colors.blueAccent),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: Colors.blueAccent),
            label: 'Resumo',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded, color: Colors.blueAccent),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
