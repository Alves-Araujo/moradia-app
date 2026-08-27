import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'novo_anuncio_screen.dart';
import '../main.dart';
import '../models/imovel.dart';
import '../models/filtro_state.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/animated_gradient_button.dart';

class CentroDoMapa extends StatefulWidget {
  final String tipoUsuario;

  const CentroDoMapa({super.key, required this.tipoUsuario});

  @override
  State<CentroDoMapa> createState() => _CentroDoMapaState();
}

class _CentroDoMapaState extends State<CentroDoMapa>
    with SingleTickerProviderStateMixin {

  // coordenada de fallback caso o gps nao responda
  final LatLng _posicaoInicial = const LatLng(-22.2528, -45.6976);
  GoogleMapController? _mapController;

  final TextEditingController _buscaController = TextEditingController();

  String _modoMapaAtual = 'Normal';

  String _tipoUsuarioAtual = 'estudante';
  String _nomeUsuario = 'Usuário Hive';
  String _emailUsuario = 'usuario@hive.com';

  String _estiloMapaEscuro = '';
  String _estiloMapaLimpo = '';
  String? _estiloAtivo;

  final FiltroState _filtroState = FiltroState();
  final List<String> _todasTags = [
    'República', 'Apartamento', 'Kitnet', 'Suíte',
    'Mobiliado', 'Perto da Facul', 'Garagem', 'Com Wi-Fi',
  ];

  Set<Marker> _marcadores = {};
  bool _buscaComTexto = false;

  List<Imovel> _imoveisDoBanco = [];

  late VoidCallback _temaListener;
  late VoidCallback _filtroListener;

  late AnimationController _animIniciaisController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _tipoUsuarioAtual = widget.tipoUsuario;
    _carregarDadosUsuarioLogado();
    _carregarEstilosDoAsset();
    _obterLocalizacaoReal(); // ja dispara a busca do gps ao abrir a tela

    _animIniciaisController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animIniciaisController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animIniciaisController, curve: Curves.easeOutCubic));
    _animIniciaisController.forward();

    FirebaseFirestore.instance.collection('imoveis').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _imoveisDoBanco = snapshot.docs
              .map((doc) => Imovel.fromMap(doc.data(), doc.id))
              .toList();
        });
        _atualizarMarcadoresFiltrados();
      }
    });

    _temaListener = () {
      if (mounted) {
        _atualizarEstiloMapa();
        setState(() {});
      }
    };
    temaGlobal.addListener(_temaListener);

    _filtroListener = () {
      if (mounted) _atualizarMarcadoresFiltrados();
    };
    _filtroState.addListener(_filtroListener);

    _buscaController.addListener(() {
      setState(() => _buscaComTexto = _buscaController.text.isNotEmpty);
      _atualizarMarcadoresFiltrados();
    });
  }

  // pede permissao de localizacao e centraliza o mapa no gps
  Future<void> _obterLocalizacaoReal() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
    );

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  Future<void> _carregarDadosUsuarioLogado() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final emailFormatado = user.email!.toLowerCase().trim();

        if (mounted) {
          setState(() {
            _emailUsuario = emailFormatado;
          });
        }

        final query = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('email', isEqualTo: emailFormatado)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          if (mounted) {
            setState(() {
              _tipoUsuarioAtual = data['tipoUsuario'] ?? widget.tipoUsuario;
              _nomeUsuario = data['nome'] ?? 'Usuário Hive';
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados do usuário: $e");
    }
  }

  @override
  void dispose() {
    temaGlobal.removeListener(_temaListener);
    _filtroState.removeListener(_filtroListener);
    _filtroState.dispose();
    _buscaController.dispose();
    _animIniciaisController.dispose();
    super.dispose();
  }

  Future<void> _carregarEstilosDoAsset() async {
    _estiloMapaEscuro = await rootBundle.loadString('assets/map_styles/style_dark.json');
    _estiloMapaLimpo = await rootBundle.loadString('assets/map_styles/style_clean.json');
    if (mounted) _atualizarEstiloMapa();
  }

  void _atualizarMarcadoresFiltrados() {
    final textoBusca = _buscaController.text.toLowerCase().trim();

    final imovelFiltrados = _imoveisDoBanco.where((item) {
      if (textoBusca.isNotEmpty) {
        final combinado = '${item.titulo} ${item.descricao}'.toLowerCase();
        if (!combinado.contains(textoBusca)) return false;
      }
      if (item.tipo == TipoListing.evento) return true;
      if (item.preco > _filtroState.precoMaximo) return false;
      if (_filtroState.tagsSelecionadas.isNotEmpty) {
        final temTag = _filtroState.tagsSelecionadas
            .any((tag) => item.tags.contains(tag));
        if (!temTag) return false;
      }
      return true;
    }).toList();

    setState(() {
      _marcadores = imovelFiltrados.map((item) {
        final bool isEvento = item.tipo == TipoListing.evento;
        return Marker(
          markerId: MarkerId(item.id),
          position: item.posicao,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isEvento ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: item.titulo,
            snippet: item.descricao,
          ),
        );
      }).toSet();
    });
  }

  void _atualizarEstiloMapa() {
    if (_estiloMapaEscuro.isEmpty) return;
    String? novoEstilo;
    if (_modoMapaAtual != 'Satélite') {
      novoEstilo = temaGlobal.value == ThemeMode.dark
          ? _estiloMapaEscuro
          : _estiloMapaLimpo;
    }
    if (mounted) setState(() => _estiloAtivo = novoEstilo);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _atualizarEstiloMapa();
    _obterLocalizacaoReal();
  }

  void _mostrarFiltros() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    double precoTemp = _filtroState.precoMaximo;
    List<String> tagsTemp = List.from(_filtroState.tagsSelecionadas);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? corCardEscuro : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(30) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filtros de Busca',
                        style: AppTextStyles.heading3.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            precoTemp = 3000;
                            tagsTemp.clear();
                          });
                        },
                        icon: Icon(Icons.refresh_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey),
                        label: Text('Limpar', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Preço Máximo',
                              style: AppTextStyles.captionBold.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: gradienteSecundario,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'R\$ ${precoTemp.toInt()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: corPrimaria,
                            inactiveTrackColor: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(30),
                            thumbColor: corPrimaria,
                            overlayColor: corPrimaria.withAlpha(20),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: precoTemp,
                            min: 300,
                            max: 3000,
                            divisions: 27,
                            onChanged: (valor) {
                              setModalState(() => precoTemp = valor);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Características do Imóvel',
                    style: AppTextStyles.captionBold.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _todasTags.map((tag) {
                      bool selecionado = tagsTemp.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (selecionado) {
                              tagsTemp.remove(tag);
                            } else {
                              tagsTemp.add(tag);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: selecionado ? gradientePrincipal : null,
                            color: selecionado
                                ? null
                                : (isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(18)),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: selecionado
                                ? [
                              BoxShadow(
                                color: corPrimaria.withAlpha(30),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selecionado) ...[
                                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                tag,
                                style: TextStyle(
                                  color: selecionado ? Colors.white : (isDark ? Colors.white60 : Colors.black87),
                                  fontSize: 13,
                                  fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  AnimatedGradientButton(
                    label: 'Mostrar Resultados',
                    icon: Icons.search_rounded,
                    onTap: () {
                      _filtroState.aplicarEstado(preco: precoTemp, tags: tagsTemp);

                      Navigator.pop(context);
                      final qtd = tagsTemp.length + (precoTemp < 3000 ? 1 : 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(qtd > 0
                                  ? '$qtd filtro(s) aplicado(s) no mapa!'
                                  : 'Filtros removidos — todos os imóveis visíveis.'),
                            ],
                          ),
                          backgroundColor: corSucesso,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarPerfil() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? corCardEscuro : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(30) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        AvatarWidget(
                          nome: _nomeUsuario,
                          size: 72,
                          showOnlineIndicator: true,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Abrindo galeria de fotos...')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: corPrimaria,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? corCardEscuro : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _tipoUsuarioAtual.toLowerCase() == 'proprietario'
                          ? 'Proprietário'
                          : _tipoUsuarioAtual.toLowerCase() == 'corretor'
                          ? 'Corretor'
                          : 'Estudante',
                      style: AppTextStyles.heading3.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailUsuario,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(5) : corSucesso.withAlpha(8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: corSucesso.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: corSucesso, size: 22),
                  ),
                  title: Text(
                    'Finalizar Cadastro',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Insira documentos para habilitar recursos.',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? Colors.white24 : Colors.grey,
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarConfiguracoes() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? corCardEscuro : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(30) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Configurações',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading3.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: gradientePrincipal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dark_mode_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        'Tema do Sistema',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      trailing: DropdownButton<ThemeMode>(
                        value: temaGlobal.value,
                        underline: const SizedBox(),
                        borderRadius: BorderRadius.circular(12),
                        dropdownColor: isDark ? corSuperficieEscura : Colors.white,
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
                        ],
                        onChanged: (ThemeMode? novoModo) {
                          if (novoModo != null) {
                            setModalState(() => temaGlobal.value = novoModo);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Estilo Visual do Mapa',
                    style: AppTextStyles.captionBold.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: _botaoModoMapa('Normal', Icons.map_outlined, isDark, setModalState)),
                      const SizedBox(width: 12),
                      Expanded(child: _botaoModoMapa('Satélite', Icons.satellite_alt_rounded, isDark, setModalState)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _botaoModoMapa(String titulo, IconData icone, bool isDark, StateSetter setModalState) {
    bool isSelected = _modoMapaAtual == titulo;
    return GestureDetector(
      onTap: () {
        setModalState(() => _modoMapaAtual = titulo);
        setState(() => _modoMapaAtual = titulo);
        _atualizarEstiloMapa();
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isSelected ? gradientePrincipal : null,
          color: isSelected ? null : (isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(12)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [BoxShadow(color: corPrimaria.withAlpha(30), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Column(
          children: [
            Icon(icone, color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey), size: 28),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required Widget child,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withAlpha(50) : corPrimaria.withAlpha(20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? corCardEscuro : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                  width: 2,
                ),
              ),
              child: Center(child: child),
            ),
          ),
          if (badgeColor != null)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? corCardEscuro : Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double topOffset = MediaQuery.of(context).padding.top + 10;
    final bool isProprietario = _tipoUsuarioAtual.toLowerCase() == 'proprietario';

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(target: _posicaoInicial, zoom: 15.0),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: _marcadores,
          mapType: _modoMapaAtual == 'Satélite' ? MapType.satellite : MapType.normal,
          style: _estiloAtivo,
        ),

        Positioned(
          top: topOffset,
          left: 16,
          right: 16,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Row(
                children: [
                  _buildGlassButton(
                    child: AvatarWidget(nome: _nomeUsuario, size: 44),
                    onTap: _mostrarPerfil,
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? corCardEscuro : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withAlpha(50) : corPrimaria.withAlpha(20),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _buscaController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar locais...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search_rounded, color: corPrimaria, size: 22),
                          suffixIcon: _buscaComTexto
                              ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                            onPressed: () => _buscaController.clear(),
                          )
                              : IconButton(
                            icon: Badge(
                              isLabelVisible: _filtroState.temFiltrosAtivos,
                              smallSize: 8,
                              backgroundColor: corPrimaria,
                              child: const Icon(Icons.tune_rounded, color: corPrimaria, size: 22),
                            ),
                            onPressed: _mostrarFiltros,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildGlassButton(
                    child: Icon(Icons.settings_rounded, color: isDark ? Colors.white : Colors.black87, size: 22),
                    onTap: _mostrarConfiguracoes,
                  ),
                ],
              ),
            ),
          ),
        ),

        // botao pra focar na localizacao do usuario
        Positioned(
          bottom: isProprietario ? 84 : 20, // Sobe se o botao de anunciar estiver visivel
          right: 16,
          child: FloatingActionButton(
            heroTag: 'btnLocation',
            mini: true,
            backgroundColor: isDark ? corCardEscuro : Colors.white,
            onPressed: _obterLocalizacaoReal,
            child: Icon(Icons.my_location_rounded, color: isDark ? Colors.white : Colors.black87),
          ),
        ),

        if (isProprietario)
          Positioned(
            bottom: 20,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                gradient: gradientePrincipal,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: corPrimaria.withAlpha(60),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NovoAnuncioScreen()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_home_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Anunciar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}