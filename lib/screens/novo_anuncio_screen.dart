import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../models/imovel.dart';
import '../widgets/animated_gradient_button.dart';
import '../main.dart';

class NovoAnuncioScreen extends StatefulWidget {
  const NovoAnuncioScreen({super.key});

  @override
  State<NovoAnuncioScreen> createState() => _NovoAnuncioScreenState();
}

class _NovoAnuncioScreenState extends State<NovoAnuncioScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _precoController = TextEditingController();

  TipoListing _tipoSelecionado = TipoListing.moradia;
  final List<String> _tagsSelecionadas = [];
  bool _salvando = false;

  final List<XFile> _imagensSelecionadas = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> _todasTags = [
    'República', 'Apartamento', 'Kitnet', 'Suíte',
    'Mobiliado', 'Perto da Facul', 'Garagem', 'Com Wi-Fi'
  ];

  // abre a galeria pra escolher varias fotos de uma vez
  Future<void> _escolherImagens() async {
    try {
      final List<XFile> imagens = await _picker.pickMultiImage(
        imageQuality: 70,
      );
      if (imagens.isNotEmpty) {
        setState(() {
          _imagensSelecionadas.addAll(imagens);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar imagens: $e'), backgroundColor: corErro),
      );
    }
  }

  // tira a foto da lista de preview
  void _removerImagem(int index) {
    setState(() {
      _imagensSelecionadas.removeAt(index);
    });
  }

  // sobe as fotos pro imgbb e pega as urls de volta
  Future<List<String>> _fazerUploadDasImagens() async {
    List<String> urls = [];
    const String apiKey = 'e40e46c0ec8806fc210a96e82842971b';
    final Uri apiUrl = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');

    for (var i = 0; i < _imagensSelecionadas.length; i++) {
      try {
        final request = http.MultipartRequest('POST', apiUrl);
        request.files.add(
            await http.MultipartFile.fromPath('image', _imagensSelecionadas[i].path)
        );

        final response = await request.send();

        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonMap = json.decode(responseData);
          urls.add(jsonMap['data']['url']);
        } else {
          throw Exception('Erro na API ImgBB: HTTP ${response.statusCode}');
        }
      } catch (e) {
        throw Exception('Falha ao processar a foto ${i + 1}. Detalhes: $e');
      }
    }
    return urls;
  }

  // valida o form, geocodifica o endereco, sobe as fotos e salva no firestore
  Future<void> _salvarAnuncio() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagensSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos uma foto!'), backgroundColor: corAtencao),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final enderecoFormatado = _enderecoController.text.trim();
      double lat = -22.2528;
      double lng = -45.6976;

      // transforma o endereco digitado em lat/lng
      try {
        final geocoding = Geocoding();
        List<Location> locations = await geocoding.locationFromAddress(enderecoFormatado);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (e) {
        debugPrint("Geocoding falhou, usando coordenada de fallback: $e");
      }

      final docRef = FirebaseFirestore.instance.collection('imoveis').doc();

      final urlsImagens = await _fazerUploadDasImagens();

      final novoImovel = Imovel(
        id: docRef.id,
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        preco: double.tryParse(_precoController.text.replaceAll(',', '.')) ?? 0.0,
        posicao: LatLng(lat, lng),
        tipo: _tipoSelecionado,
        tags: _tagsSelecionadas,
        endereco: enderecoFormatado,
        fotos: urlsImagens,
      );

      final dadosImovel = novoImovel.toMap();

      await docRef.set(dadosImovel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anúncio publicado com sucesso!'), backgroundColor: corSucesso),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: corErro),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _enderecoController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? corSuperficieEscura : const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          'Novo Anúncio',
          style: AppTextStyles.heading3.copyWith(color: isDark ? Colors.white : Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fotos do Local',
                style: AppTextStyles.captionBold.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              if (_imagensSelecionadas.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagensSelecionadas.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _imagensSelecionadas.length) {
                        return GestureDetector(
                          onTap: _escolherImagens,
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: corPrimaria.withAlpha(100), width: 2, style: BorderStyle.solid),
                            ),
                            child: const Icon(Icons.add_a_photo_rounded, color: corPrimaria, size: 32),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: FileImage(File(_imagensSelecionadas[index].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _removerImagem(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                GestureDetector(
                  onTap: _escolherImagens,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(5) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(20) : Colors.grey.withAlpha(50),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, size: 40, color: corPrimaria.withAlpha(150)),
                        const SizedBox(height: 8),
                        Text(
                          'Toque para adicionar fotos',
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              RadioGroup<TipoListing>(
                groupValue: _tipoSelecionado,
                onChanged: (val) => setState(() => _tipoSelecionado = val!),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<TipoListing>(
                        title: const Text('Moradia'),
                        value: TipoListing.moradia,
                        activeColor: corPrimaria,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<TipoListing>(
                        title: const Text('Evento'),
                        value: TipoListing.evento,
                        activeColor: corAtencao,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _tituloController,
                label: 'Título do Anúncio',
                icon: Icons.title_rounded,
                isDark: isDark,
                validator: (val) => val!.isEmpty ? 'Informe o título' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _descricaoController,
                label: 'Descrição',
                icon: Icons.description_outlined,
                isDark: isDark,
                maxLines: 3,
                validator: (val) => val!.isEmpty ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _enderecoController,
                label: 'Endereço Completo',
                icon: Icons.location_on_outlined,
                isDark: isDark,
                validator: (val) => val!.isEmpty ? 'Informe o endereço' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _precoController,
                label: 'Preço (R\$)',
                icon: Icons.attach_money_rounded,
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'Informe o preço' : null,
              ),
              const SizedBox(height: 24),

              Text(
                'Características',
                style: AppTextStyles.captionBold.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _todasTags.map((tag) {
                  final selecionado = _tagsSelecionadas.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selecionado,
                    selectedColor: corPrimaria.withAlpha(50),
                    checkmarkColor: isDark ? Colors.white : corPrimaria,
                    backgroundColor: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20),
                    labelStyle: TextStyle(
                      color: selecionado
                          ? (isDark ? Colors.white : corPrimaria)
                          : (isDark ? Colors.white60 : Colors.black87),
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _tagsSelecionadas.add(tag);
                        } else {
                          _tagsSelecionadas.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              _salvando
                  ? const Center(child: CircularProgressIndicator(color: corPrimaria))
                  : AnimatedGradientButton(
                label: 'Publicar Anúncio',
                icon: Icons.cloud_upload_rounded,
                onTap: _salvarAnuncio,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : corPrimaria),
        filled: true,
        fillColor: isDark ? corCardEscuro : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
          ),
        ),
      ),
    );
  }
}