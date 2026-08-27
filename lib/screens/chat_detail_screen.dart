import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../main.dart';
import '../models/usuario.dart';
import '../services/usuario_service.dart';
import '../widgets/avatar_widget.dart';
import 'concluir_perfil_screen.dart';

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

  // cache de perfis dos remetentes, pra mostrar o avatar ao lado das mensagens
  final Map<String, Usuario> _perfisCache = {};
  final Set<String> _buscandoPerfil = {};

  Usuario? _meuPerfil;

  @override
  void initState() {
    super.initState();
    _carregarMeuPerfil();
  }

  Future<void> _carregarMeuPerfil() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final perfil = await UsuarioService.instance.buscarPorUid(uid);
    if (perfil != null && mounted) setState(() => _meuPerfil = perfil);
  }

  // busca sob demanda o perfil de quem mandou a mensagem (uma vez por uid)
  void _carregarPerfilRemetente(String uid) {
    if (uid.isEmpty || _perfisCache.containsKey(uid) || _buscandoPerfil.contains(uid)) return;
    _buscandoPerfil.add(uid);
    UsuarioService.instance.buscarPorUid(uid).then((perfil) {
      if (perfil != null && mounted) {
        setState(() => _perfisCache[uid] = perfil);
      }
    });
  }

  // manda a mensagem pra subcolecao do imovel no firestore
  void _enviarMensagem() async {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final emailUsuario = user?.email ?? 'anonimo';

    _mensagemController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.imovelId)
        .collection('mensagens')
        .add({
      'texto': texto,
      'remetente': emailUsuario,
      'remetenteUid': user?.uid ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _iniciarChamada({required bool video}) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonimo';
    final nome = (_meuPerfil?.nome.isNotEmpty ?? false) ? _meuPerfil!.nome : 'Usuário Hive';
    // callID so pode ter letras/numeros/underline -- um por conversa, assim
    // os dois lados do chat entram na mesma sala
    final callId = 'chat_${widget.imovelId}'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ZegoUIKitPrebuiltCall(
          appID: zegoAppId,
          appSign: zegoAppSign,
          userID: uid,
          userName: nome,
          callID: callId,
          config: video
              ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
              : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
        ),
      ),
    );
  }

  Future<void> _abrirConcluirPerfil() async {
    if (_meuPerfil == null) return;
    final atualizado = await Navigator.push<Usuario>(
      context,
      MaterialPageRoute(builder: (_) => ConcluirPerfilScreen(perfil: _meuPerfil!)),
    );
    if (atualizado != null && mounted) {
      setState(() => _meuPerfil = atualizado);
    }
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
    final double larguraMaxima = MediaQuery.of(context).size.width * 0.7;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            color: corPrimaria,
            onPressed: () => _iniciarChamada(video: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            color: corPrimaria,
            onPressed: () => _iniciarChamada(video: true),
          ),
        ],
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
                    final remetenteUid = msg['remetenteUid'] as String? ?? '';

                    Usuario? perfilRemetente;
                    if (!isMinha && remetenteUid.isNotEmpty) {
                      _carregarPerfilRemetente(remetenteUid);
                      perfilRemetente = _perfisCache[remetenteUid];
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: isMinha ? Alignment.centerRight : Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMinha) ...[
                              AvatarWidget(
                                nome: (perfilRemetente?.nome.isNotEmpty ?? false) ? perfilRemetente!.nome : '?',
                                fotoUrl: perfilRemetente?.fotoUrl,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                            ],
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: larguraMaxima),
                              child: Container(
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildAreaEnvio(isDark),
        ],
      ),
    );
  }

  Widget _buildAreaEnvio(bool isDark) {
    final perfilIncompleto = _meuPerfil != null && !_meuPerfil!.perfilCompleto;

    return Container(
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
        child: perfilIncompleto
            ? Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: corAtencao, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Complete seu perfil pra poder enviar mensagens.',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _abrirConcluirPerfil,
                    child: const Text('Completar', style: TextStyle(color: corPrimaria, fontWeight: FontWeight.w700)),
                  ),
                ],
              )
            : Row(
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
    );
  }
}
