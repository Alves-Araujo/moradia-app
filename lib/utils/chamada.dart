import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../main.dart';

// id deterministico pra uma dupla de usuarios -- mesmo id nos dois lados,
// nao importa quem abriu primeiro. Usado tanto pra sala de chamada (Zego)
// quanto pro id do chat direto no firestore
String gerarIdParUsuarios(String prefixo, String uid1, String uid2) {
  final ordenados = [uid1, uid2]..sort();
  return '${prefixo}_${ordenados.join('_')}'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
}

String gerarIdChamada(String uid1, String uid2) => gerarIdParUsuarios('call', uid1, uid2);

void iniciarChamadaDeVoz(
  BuildContext context, {
  required String meuUid,
  required String meuNome,
  required String outroUid,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ZegoUIKitPrebuiltCall(
        appID: zegoAppId,
        appSign: zegoAppSign,
        userID: meuUid,
        userName: meuNome,
        callID: gerarIdChamada(meuUid, outroUid),
        config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      ),
    ),
  );
}
