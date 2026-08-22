import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../main.dart';
import '../models/imovel.dart';
import '../models/filtro_state.dart';

class CentroDoMapa extends StatefulWidget {
  final String tipoUsuario;

  const CentroDoMapa({super.key, required this.tipoUsuario});

  @override
  State<CentroDoMapa> createState() => _CentroDoMapaState();
}

class _CentroDoMapaState extends State<CentroDoMapa> {
  final LatLng _posicaoInicial = const LatLng(-22.2528, -45.6976);
  final TextEditingController _buscaController = TextEditingController();

  String _modoMapaAtual = 'Normal';

  // Estilos do mapa carregados dos assets
  String _estiloMapaEscuro = '';
  String _estiloMapaLimpo = '';
  String? _estiloAtivo; // Estilo atual passado ao widget GoogleMap

  // Filtros encapsulados no FiltroState
  final FiltroState _filtroState = FiltroState();
  final List<String> _todasTags = [
    'República', 'Apartamento', 'Kitnet', 'Suíte',
    'Mobiliado', 'Perto da Facul', 'Garagem', 'Com Wi-Fi',
  ];

  Set<Marker> _marcadores = {};
  bool _buscaComTexto = false;

  // Listener guardado para poder remover no dispose
  late VoidCallback _temaListener;
  late VoidCallback _filtroListener;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _carregarEstilosDoAsset();

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

    _atualizarMarcadoresFiltrados();
  }

  @override
  void dispose() {
    // ✅ Remove listeners para evitar memory leak
    temaGlobal.removeListener(_temaListener);
    _filtroState.removeListener(_filtroListener);
    _filtroState.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarEstilosDoAsset() async {
    _estiloMapaEscuro = await rootBundle.loadString('assets/map_styles/style_dark.json');
    _estiloMapaLimpo = await rootBundle.loadString('assets/map_styles/style_clean.json');
    if (mounted) _atualizarEstiloMapa();
  }

  void _atualizarMarcadoresFiltrados() {
    final textoBusca = _buscaController.text.toLowerCase().trim();
    final imovelFiltrados = todosOsImoveis.where((item) {
      // Filtro de texto — busca no título e descrição
      if (textoBusca.isNotEmpty) {
        final combinado = '${item.titulo} ${item.descricao}'.toLowerCase();
        if (!combinado.contains(textoBusca)) return false;
      }
      if (item.tipo == TipoListing.evento) return true; // eventos sempre visíveis
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
  }

  // --- LÓGICA DE FILTROS AVANÇADOS --- //
  void _mostrarFiltros() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Estado local temporário do modal (antes de aplicar)
    double precoTemp = _filtroState.precoMaximo;
    List<String> tagsTemp = List.from(_filtroState.tagsSelecionadas);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtros de Busca',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            precoTemp = 1500;
                            tagsTemp.clear();
                          });
                        },
                        child: const Text('Limpar', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Slider de Preço
                  Text(
                    'Preço Máximo: R\$ ${precoTemp.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: precoTemp,
                    min: 300,
                    max: 3000,
                    divisions: 27,
                    activeColor: Colors.blueAccent,
                    onChanged: (valor) {
                      setModalState(() => precoTemp = valor);
                    },
                  ),
                  const Divider(height: 32),

                  // Tags de Categoria
                  const Text('Características do Imóvel', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _todasTags.map((tag) {
                      bool selecionado = tagsTemp.contains(tag);
                      return FilterChip(
                        label: Text(
                          tag,
                          style: TextStyle(
                            color: selecionado ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontSize: 13,
                          ),
                        ),
                        selected: selecionado,
                        selectedColor: Colors.blueAccent,
                        backgroundColor: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(25),
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.transparent),
                        ),
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              tagsTemp.add(tag);
                            } else {
                              tagsTemp.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Botão Aplicar — ✅ agora realmente filtra os marcadores
                  ElevatedButton(
                    onPressed: () {
                      // Aplica o estado temporário no FiltroState real via método público
                      _filtroState.aplicarEstado(preco: precoTemp, tags: tagsTemp);

                      Navigator.pop(context);
                      final qtd = tagsTemp.length + (precoTemp < 3000 ? 1 : 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(qtd > 0
                              ? '$qtd filtro(s) aplicado(s) no mapa!'
                              : 'Filtros removidos — todos os imóveis visíveis.'),
                          backgroundColor: Colors.blueAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Mostrar Resultados',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- PERFIL --- //
  void _mostrarPerfil() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white.withAlpha(242),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Meu Perfil',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  widget.tipoUsuario == 'estudante'
                      ? 'Estudante'
                      : widget.tipoUsuario == 'proprietario'
                          ? 'Proprietário'
                          : 'Corretor',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('usuario@hive.com'),
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: Colors.green),
                title: const Text('Finalizar Cadastro', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Insira documentos para habilitar recursos.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- CONFIGURAÇÕES --- //
  void _mostrarConfiguracoes() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white.withAlpha(242),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Configurações',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.dark_mode_rounded),
                    title: const Text('Tema do Sistema', style: TextStyle(fontWeight: FontWeight.w500)),
                    trailing: DropdownButton<ThemeMode>(
                      value: temaGlobal.value,
                      underline: const SizedBox(),
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
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Estilo Visual do Mapa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _botaoModoMapa('Normal', Icons.map_outlined, setModalState),
                      _botaoModoMapa('Satélite', Icons.satellite_alt_rounded, setModalState),
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

  Widget _botaoModoMapa(String titulo, IconData icone, StateSetter setModalState) {
    bool isSelected = _modoMapaAtual == titulo;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setModalState(() => _modoMapaAtual = titulo);
        setState(() => _modoMapaAtual = titulo);
        _atualizarEstiloMapa();
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icone, color: isSelected ? Colors.blueAccent : Colors.grey, size: 30),
            const SizedBox(height: 6),
            Text(
              titulo,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap, Color? badgeColor}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 48,
                height: 48,
                color: isDark ? const Color(0xFF1E1E1E).withAlpha(204) : Colors.white.withAlpha(191),
                child: IconButton(
                  icon: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 22),
                  onPressed: onTap,
                ),
              ),
            ),
          ),
        ),
        if (badgeColor != null)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    // ✅ Usa safe area real em vez de top: 55 fixo
    final double topOffset = MediaQuery.of(context).padding.top + 10;

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(target: _posicaoInicial, zoom: 15.0),
          myLocationEnabled: true,
          zoomControlsEnabled: false,
          markers: _marcadores,
          mapType: _modoMapaAtual == 'Satélite' ? MapType.satellite : MapType.normal,
          style: _estiloAtivo,
        ),

        Positioned(
          top: topOffset,
          left: 16,
          right: 16,
          child: Row(
            children: [
              _buildGlassButton(icon: Icons.person_outline_rounded, onTap: _mostrarPerfil),
              const SizedBox(width: 10),

              // Barra de pesquisa com controller e botão de limpar
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 15),
                        blurRadius: 25,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        color: isDark
                            ? const Color(0xFF1E1E1E).withAlpha(204)
                            : Colors.white.withAlpha(191),
                        child: TextField(
                          controller: _buscaController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Localiza aí 📍',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.blueAccent, size: 22),
                            suffixIcon: _buscaComTexto
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                                    onPressed: () => _buscaController.clear(),
                                  )
                                : IconButton(
                                    icon: Badge(
                                      isLabelVisible: _filtroState.temFiltrosAtivos,
                                      smallSize: 8,
                                      child: const Icon(Icons.tune_rounded, color: Colors.blueAccent),
                                    ),
                                    onPressed: _mostrarFiltros,
                                  ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildGlassButton(icon: Icons.settings_rounded, onTap: _mostrarConfiguracoes),
            ],
          ),
        ),

        // ✅ Botão "+ Anunciar" visível apenas para proprietários
        if (widget.tipoUsuario == 'proprietario')
          Positioned(
            bottom: 110,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Anunciar Imóvel'),
                    content: const Text(
                      'Para registrar um novo imóvel e enviar para moderação, conclua sua validação cadastral no Perfil.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Entendi', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add_home_rounded, color: Colors.white),
              label: const Text('Anunciar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}