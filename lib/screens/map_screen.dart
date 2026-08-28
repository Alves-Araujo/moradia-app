import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'concluir_perfil_screen.dart';
import 'detalhes_imovel_screen.dart';
import 'novo_anuncio_screen.dart';
import '../main.dart';
import '../models/imovel.dart';
import '../models/filtro_state.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/busca_service.dart';
import '../services/imobiliaria_service.dart';
import '../services/rota_service.dart';
import '../services/usuario_service.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/animated_gradient_button.dart';

class CentroDoMapa extends StatefulWidget {
  final Usuario perfil;

  const CentroDoMapa({super.key, required this.perfil});

  @override
  State<CentroDoMapa> createState() => _CentroDoMapaState();
}

class _CentroDoMapaState extends State<CentroDoMapa>
    with SingleTickerProviderStateMixin {

  GoogleMapController? _mapController;

  final TextEditingController _buscaController = TextEditingController();
  final FocusNode _buscaFocusNode = FocusNode();
  Timer? _debounceSugestoes;
  List<SugestaoBusca> _sugestoes = [];

  String _modoMapaAtual = 'Normal';

  late Usuario _perfilAtual;

  String _estiloMapaEscuro = '';
  String _estiloMapaLimpo = '';
  String? _estiloAtivo;

  final FiltroState _filtroState = FiltroState();

  Set<Marker> _marcadores = {};
  bool _buscaComTexto = false;

  List<Imovel> _imoveisDoBanco = [];

  // estado visual da rota (markers/polyline) montado a partir de
  // rotaAtivaGlobal/rotaCarregandoGlobal -- o calculo em si roda fora dessa
  // tela (ver main.dart e rota_service.dart) porque essa State e recriada
  // toda vez que o usuario troca de aba, entao nao pode ser a dona do
  // Future -- so espelha o que ja esta pronto globalmente
  Set<Marker> _marcadoresRota = {};
  Set<Polyline> _rotas = {};
  RotaAtiva? _rotaAtual;
  bool _carregandoRota = false;

  late VoidCallback _temaListener;
  late VoidCallback _filtroListener;
  late VoidCallback _rotaAtivaListener;
  late VoidCallback _rotaCarregandoListener;
  late VoidCallback _rotaErroListener;

  late AnimationController _animIniciaisController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _perfilAtual = widget.perfil;
    _carregarDadosUsuarioLogado();
    _carregarEstilosDoAsset();
    _obterLocalizacaoReal(); // ja dispara a busca do gps ao abrir a tela
    _verificarVinculoPendente();

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

    // espelha o resultado/estado de carregamento da rota, que sao globais
    // (ver comentario nos campos acima) -- inclui o valor JA atual na hora
    // de montar essa tela, pra cobrir o caso de trocar de aba enquanto uma
    // rota ainda esta sendo calculada em outra instancia que ja foi destruida
    _sincronizarComRotaGlobal();
    _rotaAtivaListener = () {
      if (mounted) _atualizarEstadoDaRota();
    };
    rotaAtivaGlobal.addListener(_rotaAtivaListener);
    _rotaCarregandoListener = () {
      if (mounted) setState(() => _carregandoRota = rotaCarregandoGlobal.value);
    };
    rotaCarregandoGlobal.addListener(_rotaCarregandoListener);
    _rotaErroListener = () {
      final erro = rotaErroGlobal.value;
      if (erro == null || !mounted) return;
      rotaErroGlobal.value = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível calcular a rota: $erro'), backgroundColor: corErro),
      );
    };
    rotaErroGlobal.addListener(_rotaErroListener);

    _buscaController.addListener(() {
      setState(() => _buscaComTexto = _buscaController.text.isNotEmpty);
      _atualizarMarcadoresFiltrados();

      // debounce so pras sugestoes -- evita recalcular a lista a cada tecla
      _debounceSugestoes?.cancel();
      _debounceSugestoes = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _sugestoes = BuscaService.instance.buscarSugestoes(_buscaController.text, _imoveisDoBanco);
        });
      });
    });

    _buscaFocusNode.addListener(() => setState(() {}));
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
      if (user == null) return;
      final perfil = await UsuarioService.instance.buscarPorUid(user.uid);
      if (perfil != null && mounted) {
        setState(() => _perfilAtual = perfil);
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados do usuário: $e");
    }
  }

  // se o e-mail dessa conta bate com o de uma imobiliaria ainda pendente
  // (algum corretor se vinculou a ela), oferece a confirmacao aqui
  Future<void> _verificarVinculoPendente() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    final pendente = await ImobiliariaService.instance.buscarPendentePorEmail(email);
    if (pendente == null || !mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? corCardEscuro : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.apartment_rounded, color: corPrimaria, size: 40),
              const SizedBox(height: 16),
              Text(
                'Você é responsável por "${pendente.nome}"?',
                style: AppTextStyles.heading3.copyWith(color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Um ou mais corretores pediram vínculo com essa imobiliária usando esse e-mail. Confirme pra liberar o perfil público deles.',
                style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white54 : Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AnimatedGradientButton(
                label: 'Confirmar vínculo',
                onTap: () async {
                  await ImobiliariaService.instance.confirmar(pendente.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text('Agora não', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selecionarSugestao(SugestaoBusca sugestao) {
    _buscaController.text = sugestao.texto;
    _buscaFocusNode.unfocus();
    setState(() => _sugestoes = []);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(sugestao.destino, 16));
  }

  @override
  void dispose() {
    temaGlobal.removeListener(_temaListener);
    _filtroState.removeListener(_filtroListener);
    rotaAtivaGlobal.removeListener(_rotaAtivaListener);
    rotaCarregandoGlobal.removeListener(_rotaCarregandoListener);
    rotaErroGlobal.removeListener(_rotaErroListener);
    _filtroState.dispose();
    _debounceSugestoes?.cancel();
    _buscaController.dispose();
    _buscaFocusNode.dispose();
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
      // evento nao tem preco de aluguel, entao pula so o filtro de preco
      if (item.tipo != TipoListing.evento && item.preco > _filtroState.precoMaximo) {
        return false;
      }
      if (_filtroState.tagsSelecionadas.isNotEmpty) {
        final temTodasAsTags = _filtroState.tagsSelecionadas
            .every((tag) => item.tags.contains(tag));
        if (!temTodasAsTags) return false;
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
          onTap: () => _abrirDetalhesImovel(item),
        );
      }).toSet();
    });
  }

  // agora o toque em qualquer marker (moradia ou evento) abre a pagina de
  // detalhes -- o calculo de rota mora la dentro, nao mais aqui no mapa
  void _abrirDetalhesImovel(Imovel imovel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalhesImovelScreen(imovel: imovel)),
    );
  }

  // so mexe nos campos, sem setState -- usado no initState (onde o setState
  // e desnecessario e arriscado, ja que o primeiro build ainda nem rodou)
  void _sincronizarComRotaGlobal() {
    final ativa = rotaAtivaGlobal.value;
    _rotaAtual = ativa;
    _carregandoRota = rotaCarregandoGlobal.value;
    if (ativa == null) {
      _rotas = {};
      _marcadoresRota = {};
      return;
    }
    _rotas = {
      Polyline(
        polylineId: const PolylineId('rota_ativa'),
        points: ativa.resultado.pontos,
        color: corPrimaria,
        width: 5,
      ),
    };
    _marcadoresRota = {
      Marker(
        markerId: const MarkerId('rota_origem'),
        position: ativa.origem,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('rota_destino'),
        position: ativa.destino,
        infoWindow: InfoWindow(title: ativa.nomeDestino),
      ),
    };
  }

  // reconstroi markers/polyline a partir do rotaAtivaGlobal atual e enquadra
  // a camera -- chamado toda vez que o valor global muda (depois do primeiro build)
  void _atualizarEstadoDaRota() {
    setState(_sincronizarComRotaGlobal);

    final ativa = rotaAtivaGlobal.value;
    if (ativa != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(RotaService.calcularBounds(ativa.resultado.pontos), 60),
      );
    }
  }

  void _limparRota() {
    rotaAtivaGlobal.value = null;
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
                    children: tagsDisponiveis.map((tag) {
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
      builder: (sheetContext) {
        return _PerfilPreview(
          perfil: _perfilAtual,
          onConcluirPerfil: () async {
            Navigator.pop(sheetContext);
            final atualizado = await Navigator.push<Usuario>(
              context,
              MaterialPageRoute(builder: (_) => ConcluirPerfilScreen(perfil: _perfilAtual)),
            );
            if (atualizado != null && mounted) {
              setState(() => _perfilAtual = atualizado);
            }
          },
          onSair: () {
            Navigator.pop(sheetContext);
            _confirmarLogout();
          },
        );
      },
    );
  }

  // pede confirmacao, desloga do firebase e limpa a pilha de telas -- a
  // AuthGate, la no main.dart, percebe sozinha que nao tem mais usuario e
  // troca pra tela de login (mesmo mecanismo usado no resto do app; nao
  // usamos rotas nomeadas em nenhum lugar, entao aqui tambem nao)
  Future<void> _confirmarLogout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? corCardEscuro : Colors.white,
        title: const Text('Sair da conta?'),
        content: const Text('Você vai precisar entrar de novo pra acessar o app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair', style: TextStyle(color: corErro, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    await AuthService.instance.sair();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _mostrarConfiguracoes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // recalculado aqui dentro (a partir do temaGlobal, nao do Theme.of
            // que so seria atualizado no proximo build da tela por baixo) --
            // antes isDark vinha de fora do StatefulBuilder e ficava preso no
            // valor de quando a folha abriu, so atualizando se fechasse e
            // abrisse ela de novo
            final bool isDark = temaGlobal.value == ThemeMode.dark ||
                (temaGlobal.value == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark);
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                color: isDark ? corCardEscuro : Colors.white,
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
                  const SizedBox(height: 24),
                  Divider(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmarLogout();
                    },
                    icon: const Icon(Icons.logout_rounded, color: corErro, size: 18),
                    label: const Text('Sair da conta', style: TextStyle(color: corErro, fontWeight: FontWeight.w600)),
                  ),
                  ],
                ),
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
    final bool podeAnunciar = _perfilAtual.perfilCompleto &&
        _perfilAtual.tipoUsuario.toLowerCase() == 'proprietario';

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(target: posicaoInatel, zoom: 15.0),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: {..._marcadores, ..._marcadoresRota},
          polylines: _rotas,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _buildGlassButton(
                        child: AvatarWidget(nome: _perfilAtual.nome, fotoUrl: _perfilAtual.fotoUrl, size: 44),
                        onTap: _mostrarPerfil,
                        badgeColor: _perfilAtual.perfilCompleto ? null : corErro,
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
                            focusNode: _buscaFocusNode,
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
                  if (_sugestoes.isNotEmpty && _buscaFocusNode.hasFocus)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: isDark ? corCardEscuro : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(isDark ? 60 : 15), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _sugestoes.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1, indent: 56,
                          color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20),
                        ),
                        itemBuilder: (context, index) {
                          final sugestao = _sugestoes[index];
                          final IconData icone = switch (sugestao.tipo) {
                            TipoSugestao.cidade => Icons.location_city_rounded,
                            TipoSugestao.faculdade => Icons.school_rounded,
                            TipoSugestao.moradia => Icons.home_rounded,
                          };
                          return ListTile(
                            leading: Icon(icone, color: corPrimaria),
                            title: Text(
                              sugestao.texto,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            ),
                            onTap: () => _selecionarSugestao(sugestao),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // cartao com a distancia/duracao da rota pedida na tela de detalhes,
        // ou um spinner enquanto ela ainda ta sendo calculada
        if (_carregandoRota || _rotaAtual != null)
          Positioned(
            top: topOffset + 68,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? corCardEscuro : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(isDark ? 60 : 15), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: _carregandoRota
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: corPrimaria),
                        ),
                        const SizedBox(width: 12),
                        Text('Calculando rota...', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(gradient: gradientePrincipal, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Até ${_rotaAtual!.nomeDestino}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_rotaAtual!.resultado.distanciaTexto} · ${_rotaAtual!.resultado.duracaoTexto}',
                                style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _limparRota,
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white38 : Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),

        // botao pra focar na localizacao do usuario
        Positioned(
          bottom: podeAnunciar ? 84 : 20, // Sobe se o botao de anunciar estiver visivel
          right: 16,
          child: FloatingActionButton(
            heroTag: 'btnLocation',
            mini: true,
            backgroundColor: isDark ? corCardEscuro : Colors.white,
            onPressed: _obterLocalizacaoReal,
            child: Icon(Icons.my_location_rounded, color: isDark ? Colors.white : Colors.black87),
          ),
        ),

        if (podeAnunciar)
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

// previa rapida do perfil (avatar, nome, selo de completo/incompleto) --
// a edicao de verdade agora mora toda em ConcluirPerfilScreen
class _PerfilPreview extends StatelessWidget {
  final Usuario perfil;
  final VoidCallback onConcluirPerfil;
  final VoidCallback onSair;

  const _PerfilPreview({required this.perfil, required this.onConcluirPerfil, required this.onSair});

  String get _rotuloTipo {
    switch (perfil.tipoUsuario.toLowerCase()) {
      case 'proprietario':
        return 'Proprietário';
      case 'corretor':
        return perfil.subtipoCorretor == 'empresa' ? 'Corretor (Empresa)' : 'Corretor Autônomo';
      case 'estudante':
        return 'Estudante';
      default:
        return 'Tipo de conta não definido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final corSelo = perfil.perfilCompleto ? corSucesso : corAtencao;

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
                AvatarWidget(
                  nome: perfil.nome.isNotEmpty ? perfil.nome : perfil.email,
                  fotoUrl: perfil.fotoUrl,
                  size: 72,
                  showOnlineIndicator: true,
                ),
                const SizedBox(height: 16),
                Text(
                  perfil.nome.isNotEmpty ? perfil.nome : 'Usuário Hive',
                  style: AppTextStyles.heading3.copyWith(color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(_rotuloTipo, style: AppTextStyles.captionBold.copyWith(color: corPrimaria)),
                const SizedBox(height: 4),
                Text(
                  perfil.email,
                  style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: corSelo.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    perfil.perfilCompleto ? 'Perfil completo' : 'Perfil incompleto',
                    style: TextStyle(color: corSelo, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AnimatedGradientButton(
            label: perfil.perfilCompleto ? 'Editar Perfil' : 'Concluir Perfil',
            onTap: onConcluirPerfil,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onSair,
            icon: const Icon(Icons.logout_rounded, color: corErro, size: 18),
            label: const Text('Sair da conta', style: TextStyle(color: corErro, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}