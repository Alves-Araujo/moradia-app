import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../main.dart';
import '../models/avaliacao.dart';
import '../models/imovel.dart';
import '../models/perfil_publico.dart';
import '../services/avaliacao_service.dart';
import '../services/perfil_publico_service.dart';
import '../services/rota_service.dart';
import '../utils/localizacao.dart';
import '../utils/tempo.dart';
import '../widgets/animated_gradient_button.dart';
import '../widgets/avatar_widget.dart';
import 'chat_detail_screen.dart';
import 'perfil_publico_screen.dart';

// pagina dedicada de detalhes -- aberta ao tocar num marker do mapa ou num
// card na aba Resumo. O calculo de rota so dispara o pedido (rotaPendenteGlobal)
// e volta pro mapa principal, que e quem de fato traca e mostra a rota
class DetalhesImovelScreen extends StatefulWidget {
  final Imovel imovel;
  const DetalhesImovelScreen({super.key, required this.imovel});

  @override
  State<DetalhesImovelScreen> createState() => _DetalhesImovelScreenState();
}

class _DetalhesImovelScreenState extends State<DetalhesImovelScreen> {
  bool _buscandoLocalizacao = false;

  void _dispararRotaEVoltar({required LatLng origem, required LatLng destino, required String nomeDestino}) {
    rotaPendenteGlobal.value = RotaPendente(origem: origem, destino: destino, nomeDestino: nomeDestino);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _rotaDaMinhaLocalizacaoAteAqui() async {
    setState(() => _buscandoLocalizacao = true);
    LatLng? origem;
    try {
      origem = await obterLocalizacaoAtual();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao obter sua localização: $e'), backgroundColor: corErro),
        );
      }
    }
    if (!mounted) return;
    setState(() => _buscandoLocalizacao = false);

    if (origem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não conseguimos acessar sua localização atual.'), backgroundColor: corErro),
      );
      return;
    }
    _dispararRotaEVoltar(origem: origem, destino: widget.imovel.posicao, nomeDestino: widget.imovel.titulo);
  }

  Future<void> _rotaDaquiParaDestinoDigitado() async {
    final controller = TextEditingController();
    final destinoTexto = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pra onde você quer ir?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Inatel'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Traçar rota')),
        ],
      ),
    );
    if (destinoTexto == null || destinoTexto.isEmpty || !mounted) return;

    try {
      final geocoding = Geocoding();
      final locais = await geocoding.locationFromAddress(destinoTexto);
      if (locais.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não encontramos esse endereço.'), backgroundColor: corErro),
          );
        }
        return;
      }
      _dispararRotaEVoltar(
        origem: widget.imovel.posicao,
        destino: LatLng(locais.first.latitude, locais.first.longitude),
        nomeDestino: destinoTexto,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar esse endereço: $e'), backgroundColor: corErro),
        );
      }
    }
  }

  void _abrirModalDeRota() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? corCardEscuro : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(30) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Como você quer traçar a rota?',
                  style: AppTextStyles.heading3.copyWith(color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 16),
                _opcaoRota(
                  isDark: isDark,
                  icone: Icons.my_location_rounded,
                  titulo: 'Definir rota até o local do anúncio',
                  subtitulo: 'Da sua localização atual até aqui',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _rotaDaMinhaLocalizacaoAteAqui();
                  },
                ),
                const SizedBox(height: 12),
                _opcaoRota(
                  isDark: isDark,
                  icone: Icons.edit_location_alt_rounded,
                  titulo: 'Ver rota da casa até um destino',
                  subtitulo: 'Digite pra onde você quer ir',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _rotaDaquiParaDestinoDigitado();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _opcaoRota({
    required bool isDark,
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(gradient: gradientePrincipal, borderRadius: BorderRadius.circular(12)),
              child: Icon(icone, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final imovel = widget.imovel;
    final bool isEvento = imovel.tipo == TipoListing.evento;

    return Scaffold(
      backgroundColor: isDark ? corSuperficieEscura : const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // o design que antes era do badge "casa/evento" (que nao tinha
        // funcao nenhuma, so decorativo, e ainda vinha quebrado por causa do
        // bug de largura) foi reaproveitado no botao de voltar de verdade --
        // leadingWidth explicito + Center garante que o badge fique
        // centralizado no espaco reservado da AppBar, nao so dentro de si mesmo
        leadingWidth: 64,
        leading: Center(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isEvento ? gradienteEvento : gradientePrincipal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (imovel.fotos.isNotEmpty) ...[
            SizedBox(
              height: 240,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: imovel.fotos.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 10, offset: const Offset(0, 4))],
                      image: DecorationImage(image: NetworkImage(imovel.fotos[index]), fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(imovel.titulo, style: AppTextStyles.heading3.copyWith(color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: corPrimaria.withAlpha(160)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        imovel.endereco.isNotEmpty ? imovel.endereco : 'Endereço não informado',
                        style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)),
                const SizedBox(height: 16),

                Text(imovel.descricao, style: AppTextStyles.body.copyWith(color: isDark ? Colors.white70 : Colors.black87)),

                if (imovel.tags.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: imovel.tags.map((tag) {
                      return Chip(
                        label: Text(tag, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : corPrimaria)),
                        backgroundColor: isDark ? Colors.white.withAlpha(8) : corPrimaria.withAlpha(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? Colors.white.withAlpha(10) : corPrimaria.withAlpha(20)),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],

                if (!isEvento) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(5) : corPrimaria.withAlpha(6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withAlpha(8) : corPrimaria.withAlpha(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Aluguel mensal', style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey)),
                        ShaderMask(
                          shaderCallback: (bounds) => gradienteSecundario.createShader(bounds),
                          child: Text(
                            'R\$ ${imovel.preco.toInt()}/mês',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                _buildSecaoAnunciante(isDark),

                const SizedBox(height: 24),
                Text('Rota', style: AppTextStyles.captionBold.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
                const SizedBox(height: 12),
                AnimatedGradientButton(
                  label: 'Calcular Rota',
                  icon: Icons.alt_route_rounded,
                  isLoading: _buscandoLocalizacao,
                  onTap: _abrirModalDeRota,
                ),

                if (!isEvento) ...[
                  const SizedBox(height: 16),
                  AnimatedGradientButton(
                    label: 'Enviar Mensagem',
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            imovelTitulo: imovel.titulo,
                            imovelId: imovel.id,
                            donoUid: imovel.donoUid,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoAnunciante(bool isDark) {
    if (widget.imovel.donoUid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<PerfilPublico?>(
      future: PerfilPublicoService.instance.buscarPorUid(widget.imovel.donoUid),
      builder: (context, snapshot) {
        final carregando = snapshot.connectionState == ConnectionState.waiting;
        final dono = snapshot.data;
        final nomeExibido = (dono?.nome.isNotEmpty ?? false) ? dono!.nome : 'Anunciante';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: isDark ? corCardEscuro : Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anunciante', style: AppTextStyles.captionBold.copyWith(color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 12),
              Row(
                children: [
                  AvatarWidget(nome: nomeExibido, fotoUrl: dono?.fotoUrl, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomeExibido,
                          style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (carregando)
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.white38 : Colors.grey),
                          )
                        else if (dono == null)
                          Text(
                            'Dados indisponíveis',
                            style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                          )
                        else ...[
                          StreamBuilder<List<Avaliacao>>(
                            stream: AvaliacaoService.instance.streamAvaliacoes('usuarios', dono.uid),
                            builder: (context, avSnap) {
                              final avaliacoes = avSnap.data ?? [];
                              if (avaliacoes.isEmpty) {
                                return Text(
                                  'Sem avaliações ainda',
                                  style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey),
                                );
                              }
                              final media = avaliacoes.map((a) => a.nota).reduce((a, b) => a + b) / avaliacoes.length;
                              return Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: corAtencao, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${media.toStringAsFixed(1)} (${avaliacoes.length})',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              );
                            },
                          ),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 6, color: corSucesso.withAlpha(180)),
                              const SizedBox(width: 5),
                              Text(
                                formatarUltimoAcesso(dono.ultimoAcesso),
                                style: AppTextStyles.caption.copyWith(color: isDark ? Colors.white38 : Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (dono != null)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PerfilPublicoScreen(pessoa: dono)),
                      ),
                      child: const Text('Ver perfil'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
