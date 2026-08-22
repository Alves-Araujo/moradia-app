import 'package:flutter/material.dart';
import '../models/imovel.dart';

class TelaResumo extends StatefulWidget {
  final String tipoUsuario;
  const TelaResumo({super.key, required this.tipoUsuario});

  @override
  State<TelaResumo> createState() => _TelaResumoState();
}

class _TelaResumoState extends State<TelaResumo> {
  String _filtroTipo = 'Todos';

  List<Imovel> get _imoveisFiltrados {
    if (_filtroTipo == 'Todos') return todosOsImoveis;
    if (_filtroTipo == 'Moradias') {
      return todosOsImoveis.where((i) => i.tipo == TipoListing.moradia).toList();
    }
    return todosOsImoveis.where((i) => i.tipo == TipoListing.evento).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.only(top: topPadding + 12, left: 20, right: 20, bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 30 : 10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Imóveis Disponíveis',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(
                '${_imoveisFiltrados.length} resultado(s) encontrado(s)',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
              ),
              const SizedBox(height: 14),
              // Chips de filtro rápido
              Row(
                children: ['Todos', 'Moradias', 'Eventos'].map((label) {
                  final bool selected = _filtroTipo == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      selected: selected,
                      selectedColor: Colors.blueAccent,
                      backgroundColor: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.transparent),
                      ),
                      onSelected: (_) => setState(() => _filtroTipo = label),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Lista de imóveis
        Expanded(
          child: _imoveisFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 56, color: isDark ? Colors.white24 : Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum resultado encontrado.',
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _imoveisFiltrados.length,
                  itemBuilder: (context, index) {
                    final imovel = _imoveisFiltrados[index];
                    return _CardImovel(imovel: imovel, isDark: isDark);
                  },
                ),
        ),
      ],
    );
  }
}

class _CardImovel extends StatelessWidget {
  final Imovel imovel;
  final bool isDark;

  const _CardImovel({required this.imovel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bool isEvento = imovel.tipo == TipoListing.evento;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => _DetalheImovel(imovel: imovel, isDark: isDark),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isEvento
                      ? Colors.orange.withAlpha(30)
                      : Colors.blueAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isEvento ? Icons.celebration_rounded : Icons.home_rounded,
                  color: isEvento ? Colors.orange : Colors.blueAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      imovel.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      imovel.descricao,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (imovel.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: imovel.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(12) : Colors.grey.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Preço ou badge
              if (!isEvento)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R\$ ${imovel.preco.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blueAccent,
                      ),
                    ),
                    Text(
                      '/mês',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Evento',
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetalheImovel extends StatelessWidget {
  final Imovel imovel;
  final bool isDark;

  const _DetalheImovel({required this.imovel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bool isEvento = imovel.tipo == TipoListing.evento;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            imovel.titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white54 : Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  imovel.endereco.isNotEmpty ? imovel.endereco : 'Endereço não informado',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Text(
            imovel.descricao,
            style: const TextStyle(fontSize: 15),
          ),
          if (imovel.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imovel.tags.map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  backgroundColor: isDark ? Colors.white.withAlpha(12) : Colors.grey.withAlpha(25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.transparent),
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          if (!isEvento)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mensagem enviada ao anunciante!'),
                      backgroundColor: Colors.blueAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: const Text(
                  'Enviar Mensagem',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
