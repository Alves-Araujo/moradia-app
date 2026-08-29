import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/filtro_state.dart' show cidadeFiltroGlobal;
import '../models/imovel.dart';
import '../utils/moeda.dart';
import '../models/usuario.dart';
import 'detalhes_imovel_screen.dart';

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
          // o filtro de cidade e global (mesmo seletor que aparece no mapa),
          // entao escuta ele aqui tambem pra essa lista respeitar a mesma escolha
          child: ValueListenableBuilder<String?>(
            valueListenable: cidadeFiltroGlobal,
            builder: (context, cidadeFiltro, _) => StreamBuilder<QuerySnapshot>(
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
                if (cidadeFiltro != null && i.cidade != cidadeFiltro) return false;
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetalhesImovelScreen(imovel: imovel)),
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
                          formatarPreco(imovel.preco),
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
