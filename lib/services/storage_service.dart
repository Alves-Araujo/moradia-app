import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

// upload de midia do chat (fotos e audios) pro firebase storage
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  Future<String> enviarArquivo(File arquivo, String caminho) async {
    final ref = FirebaseStorage.instance.ref(caminho);
    await ref.putFile(arquivo);
    return ref.getDownloadURL();
  }
}
