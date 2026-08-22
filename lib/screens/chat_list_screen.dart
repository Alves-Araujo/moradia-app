import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';

/// Modelo de conversa para exibição na lista de chats.
class _Conversa {
  final String id;
  final String nome;
  final String ultimaMensagem;
  final String horario;
  final IconData avatar;
  final bool naoLida;

  const _Conversa({
    required this.id,
    required this.nome,
    required this.ultimaMensagem,
    required this.horario,
    required this.avatar,
    this.naoLida = false,
  });
}

class TelaListaChats extends StatelessWidget {
  const TelaListaChats({super.key});

  static const List<_Conversa> _conversas = [
    _Conversa(
      id: 'c1',
      nome: 'República Byte House',
      ultimaMensagem: 'Ainda tem vaga disponível?',
      horario: '10:42',
      avatar: Icons.house_rounded,
      naoLida: true,
    ),
    _Conversa(
      id: 'c2',
      nome: 'Ana — Kitnet Boa Vista',
      ultimaMensagem: 'Pode visitar sábado de manhã!',
      horario: 'Ontem',
      avatar: Icons.person_rounded,
    ),
    _Conversa(
      id: 'c3',
      nome: 'Carlos — Apt. Inatel',
      ultimaMensagem: 'Enviei as fotos do quarto.',
      horario: 'Seg',
      avatar: Icons.person_rounded,
      naoLida: true,
    ),
    _Conversa(
      id: 'c4',
      nome: 'Suporte Hive',
      ultimaMensagem: 'Seu cadastro foi aprovado ✅',
      horario: '15/08',
      avatar: Icons.support_agent_rounded,
    ),
  ];

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
          child: Row(
            children: [
              const Text(
                'Conversas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.blueAccent),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Lista de conversas
        Expanded(
          child: _conversas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 56, color: isDark ? Colors.white24 : Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma conversa ainda.',
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _conversas.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 76,
                    color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20),
                  ),
                  itemBuilder: (context, index) {
                    final conversa = _conversas[index];
                    return _ItemConversa(conversa: conversa, isDark: isDark);
                  },
                ),
        ),
      ],
    );
  }
}

class _ItemConversa extends StatelessWidget {
  final _Conversa conversa;
  final bool isDark;

  const _ItemConversa({required this.conversa, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blueAccent.withAlpha(25),
        child: Icon(conversa.avatar, color: Colors.blueAccent, size: 24),
      ),
      title: Text(
        conversa.nome,
        style: TextStyle(
          fontWeight: conversa.naoLida ? FontWeight.bold : FontWeight.w500,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        conversa.ultimaMensagem,
        style: TextStyle(
          fontSize: 13,
          color: conversa.naoLida
              ? (isDark ? Colors.white70 : Colors.black87)
              : (isDark ? Colors.white38 : Colors.grey),
          fontWeight: conversa.naoLida ? FontWeight.w500 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            conversa.horario,
            style: TextStyle(
              fontSize: 12,
              color: conversa.naoLida ? Colors.blueAccent : (isDark ? Colors.white38 : Colors.grey),
            ),
          ),
          if (conversa.naoLida) ...[
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaChatDetalhe(
              nomeContato: conversa.nome,
              conversaId: conversa.id,
            ),
          ),
        );
      },
    );
  }
}
