import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/imovel.dart';
import '../models/usuario.dart';
import '../widgets/animated_gradient_button.dart';
import 'chat_detail_screen.dart';

class TelaResumo extends StatefulWidget {
  final Usuario perfil;
  const TelaResumo({super.key, required this.perfil});

  @override
  State<TelaResumo> createState() => _TelaResumoState();
}

class _TelaResumoState extends State<TelaResumo> with SingleTickerProviderStateMixin {
  String _filtroTipo = 'Todos';
  late AnimationController _listAnimController;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimController.forward();
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
  }

  void _mudarFiltro(String novoFiltro) {
    setState(() => _filtroTipo = novoFiltro);
    _listAnimController.reset();
    _listAnimController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // header com gradiente
        Container(
          padding: EdgeInsets.only(top: topPadding + 12, left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [corCardEscuro, corSuperficieEscura]
                  : [Colors.white, const Color(0xFFF8F7FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 40 : 8),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Imóveis Disponíveis',
                          style: AppTextStyles.heading2.copyWith(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Buscando resultados em tempo real...',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: gradientePrincipal,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: corPrimaria.withAlpha(40),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // chips de filtro rapido
              Row(
                children: ['Todos', 'Moradias', 'Eventos'].map((label) {
                  final bool selected = _filtroTipo == label;
                  final bool isEvento = label == 'Eventos';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _mudarFiltro(label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? (isEvento ? gradienteEvento : gradientePrincipal)
                              : null,
                          color: selected
                              ? null
                              : (isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: selected
                              ? [
                            BoxShadow(
                              color: (isEvento ? corAtencao : corPrimaria).withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                              : [],
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.black87),
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // lista de imoveis vindo do Firestore
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('imoveis').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: corPrimaria));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Erro ao carregar dados.', style: AppTextStyles.body.copyWith(color: corErro)),
                );
              }

              final imoveisDoBanco = snapshot.data?.docs.map((doc) {
                return Imovel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              }).toList() ?? [];

              final imoveisFiltrados = imoveisDoBanco.where((i) {
                if (_filtroTipo == 'Todos') return true;
                if (_filtroTipo == 'Moradias') return i.tipo == TipoListing.moradia;
                return i.tipo == TipoListing.evento;
              }).toList();

              if (imoveisFiltrados.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: isDark ? Colors.white.withAlpha(51) : Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum resultado encontrado.',
                        style: AppTextStyles.body.copyWith(
                          color: isDark ? Colors.white30 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: imoveisFiltrados.length,
                itemBuilder: (context, index) {
                  final imovel = imoveisFiltrados[index];

                  final delay = (index * 0.08).clamp(0.0, 0.6);
                  final end = (delay + 0.4).clamp(0.0, 1.0);
                  final slideAnim = Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _listAnimController,
                    curve: Interval(delay, end, curve: Curves.easeOutCubic),
                  ));
                  final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _listAnimController,
                      curve: Interval(delay, end, curve: Curves.easeOut),
                    ),
                  );

                  return FadeTransition(
                    opacity: fadeAnim,
                    child: SlideTransition(
                      position: slideAnim,
                      child: _CardImovel(imovel: imovel, isDark: isDark),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// card individual de cada imovel na lista
class _CardImovel extends StatelessWidget {
  final Imovel imovel;
  final bool isDark;

  const _CardImovel({required this.imovel, required this.isDark});

  IconData _getTagIcon(String tag) {
    switch (tag) {
      case 'República': return Icons.groups_rounded;
      case 'Apartamento': return Icons.apartment_rounded;
      case 'Kitnet': return Icons.door_back_door_rounded;
      case 'Suíte': return Icons.king_bed_rounded;
      case 'Mobiliado': return Icons.chair_rounded;
      case 'Perto da Facul': return Icons.school_rounded;
      case 'Garagem': return Icons.garage_rounded;
      case 'Com Wi-Fi': return Icons.wifi_rounded;
      case 'Exclusivo para Mulheres': return Icons.woman_rounded;
      default: return Icons.label_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEvento = imovel.tipo == TipoListing.evento;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? corCardEscuro : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: isDark ? corCardEscuro : Colors.white,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              builder: (_) => _DetalheImovel(imovel: imovel, isDark: isDark),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // capa do card (foto ou icone)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: imovel.fotos.isEmpty ? (isEvento ? gradienteEvento : gradientePrincipal) : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isEvento ? corAtencao : corPrimaria).withAlpha(30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: imovel.fotos.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imovel.fotos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        isEvento ? Icons.celebration_rounded : Icons.home_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  )
                      : Icon(
                    isEvento ? Icons.celebration_rounded : Icons.home_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // info do imovel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        imovel.titulo,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        imovel.descricao,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (imovel.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: imovel.tags.take(2).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withAlpha(10) : corPrimaria.withAlpha(10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getTagIcon(tag),
                                    size: 12,
                                    color: isDark ? Colors.white.withAlpha(127) : corPrimaria.withAlpha(160),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white.withAlpha(127) : corPrimaria.withAlpha(180),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isEvento)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: gradienteSecundario,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: corDestaque.withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'R\$ ${imovel.preco.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '/mês',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withAlpha(180),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: gradienteEvento,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Evento',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// tela de detalhes quando clica num imovel
class _DetalheImovel extends StatelessWidget {
  final Imovel imovel;
  final bool isDark;

  const _DetalheImovel({required this.imovel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bool isEvento = imovel.tipo == TipoListing.evento;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // barrinha
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

          // carrossel de fotos, se tiver
          if (imovel.fotos.isNotEmpty)
            SizedBox(
              height: 220,
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(imovel.fotos[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            )
          else
          // sem foto? cai nesse header simples
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: isEvento ? gradienteEvento : gradientePrincipal,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      isEvento ? Icons.celebration_rounded : Icons.home_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  imovel.titulo,
                  style: AppTextStyles.heading3.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: corPrimaria.withAlpha(160)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        imovel.endereco.isNotEmpty ? imovel.endereco : 'Endereço não informado',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)),
                const SizedBox(height: 16),

                Text(
                  imovel.descricao,
                  style: AppTextStyles.body.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),

                if (imovel.tags.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: imovel.tags.map((tag) {
                      return Chip(
                        label: Text(tag, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : corPrimaria)),
                        backgroundColor: isDark ? Colors.white.withAlpha(8) : corPrimaria.withAlpha(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? Colors.white.withAlpha(10) : corPrimaria.withAlpha(20),
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),

                if (!isEvento) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(5) : corPrimaria.withAlpha(6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(8) : corPrimaria.withAlpha(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Aluguel mensal',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => gradienteSecundario.createShader(bounds),
                          child: Text(
                            'R\$ ${imovel.preco.toInt()}/mês',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  AnimatedGradientButton(
                    label: 'Enviar Mensagem',
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(
                            anuncianteNome: 'Proprietário',
                            imovelTitulo: imovel.titulo,
                            imovelId: imovel.id,
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
}