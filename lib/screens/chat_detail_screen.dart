import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class ChatDetailScreen extends StatefulWidget {
  final String anuncianteNome;
  final String imovelTitulo;
  final String imovelId;

  const ChatDetailScreen({
    super.key,
    required this.anuncianteNome,
    required this.imovelTitulo,
    required this.imovelId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _mensagemController = TextEditingController();

  // Envia a mensagem para a subcolecao do Firestore correspondente ao imovel
  void _enviarMensagem() async {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty) return;

    final emailUsuario = FirebaseAuth.instance.currentUser?.email ?? 'anonimo';

    _mensagemController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.imovelId)
        .collection('mensagens')
        .add({
      'texto': texto,
      'remetente': emailUsuario,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _mensagemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final emailUsuario = FirebaseAuth.instance.currentUser?.email ?? 'anonimo';
    final double larguraMaxima = MediaQuery.of(context).size.width * 0.75;

    return Scaffold(
      backgroundColor: isDark ? corSuperficieEscura : const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: isDark ? corCardEscuro : Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.anuncianteNome,
              style: AppTextStyles.bodyBold.copyWith(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            Text(
              'Ref: ${widget.imovelTitulo}',
              style: AppTextStyles.caption.copyWith(
                color: corPrimaria,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.imovelId)
                  .collection('mensagens')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: corPrimaria));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Envie a primeira mensagem!',
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  );
                }

                final mensagens = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: mensagens.length,
                  itemBuilder: (context, index) {
                    final msg = mensagens[index].data() as Map<String, dynamic>;
                    final bool isMinha = msg['remetente'] == emailUsuario;

                    return Align(
                      alignment: isMinha ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(maxWidth: larguraMaxima),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMinha
                              ? corPrimaria
                              : (isDark ? Colors.white.withAlpha(15) : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMinha ? 16 : 4),
                            bottomRight: Radius.circular(isMinha ? 4 : 16),
                          ),
                          boxShadow: [
                            if (!isMinha)
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Text(
                          msg['texto'] ?? '',
                          style: TextStyle(
                            color: isMinha
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? corCardEscuro : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensagemController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        filled: true,
                        fillColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: corPrimaria,
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
          ),
        ],
      ),
    );
  }
}