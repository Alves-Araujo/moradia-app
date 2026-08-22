import 'package:flutter/material.dart';

class TelaChatDetalhe extends StatefulWidget {
  final String nomeContato;
  final String conversaId;

  const TelaChatDetalhe({
    super.key,
    required this.nomeContato,
    required this.conversaId,
  });

  @override
  State<TelaChatDetalhe> createState() => _TelaChatDetalheState();
}

class _Mensagem {
  final String texto;
  final bool isUsuario;
  final String horario;

  const _Mensagem({
    required this.texto,
    required this.isUsuario,
    required this.horario,
  });
}

class _TelaChatDetalheState extends State<TelaChatDetalhe> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_Mensagem> _mensagens = [
    const _Mensagem(texto: 'Oi! Vi o anúncio do imóvel no Hive.', isUsuario: true, horario: '10:30'),
    const _Mensagem(texto: 'Olá! Sim, ainda está disponível 😊', isUsuario: false, horario: '10:32'),
    const _Mensagem(texto: 'Posso agendar uma visita?', isUsuario: true, horario: '10:33'),
    const _Mensagem(texto: 'Claro! Pode ser sábado de manhã?', isUsuario: false, horario: '10:35'),
  ];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _enviarMensagem() {
    final texto = _msgController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _mensagens.add(_Mensagem(
        texto: texto,
        isUsuario: true,
        horario: '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
      ));
      _msgController.clear();
    });

    // Scroll pro final
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueAccent.withAlpha(25),
              child: const Icon(Icons.person_rounded, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.nomeContato,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mensagens
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _mensagens.length,
              itemBuilder: (context, index) {
                final msg = _mensagens[index];
                return _BalaoMensagem(mensagem: msg, isDark: isDark);
              },
            ),
          ),

          // Barra de envio
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 8),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Mensagem...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withAlpha(12) : Colors.grey.withAlpha(20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _enviarMensagem,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalaoMensagem extends StatelessWidget {
  final _Mensagem mensagem;
  final bool isDark;

  const _BalaoMensagem({required this.mensagem, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bool eu = mensagem.isUsuario;

    return Align(
      alignment: eu ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: eu
              ? Colors.blueAccent
              : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(eu ? 16 : 4),
            bottomRight: Radius.circular(eu ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mensagem.texto,
              style: TextStyle(
                color: eu ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mensagem.horario,
              style: TextStyle(
                fontSize: 11,
                color: eu ? Colors.white70 : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
