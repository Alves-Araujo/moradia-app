import 'package:google_maps_flutter/google_maps_flutter.dart';

enum TipoListing { moradia, evento }

class Imovel {
  final String id;
  final String titulo;
  final String descricao;
  final double preco;
  final LatLng posicao;
  final TipoListing tipo;
  final List<String> tags;
  final String endereco;

  const Imovel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.preco,
    required this.posicao,
    required this.tipo,
    this.tags = const [],
    this.endereco = '',
  });
}

// dados de teste — TODO: trocar por firebase dps
final List<Imovel> todosOsImoveis = [
  const Imovel(
    id: '1',
    titulo: 'República Estudantil Central',
    descricao: 'Quarto individual · R\$ 650/mês',
    preco: 650,
    posicao: LatLng(-22.2510, -45.6950),
    tipo: TipoListing.moradia,
    tags: ['República', 'Perto da Facul', 'Com Wi-Fi'],
    endereco: 'Rua Dr. Delfino, 120 — Centro',
  ),
  const Imovel(
    id: '2',
    titulo: 'Kitnet Mobiliada - Bairro Boa Vista',
    descricao: 'Kitnet completa · R\$ 800/mês',
    preco: 800,
    posicao: LatLng(-22.2545, -45.6990),
    tipo: TipoListing.moradia,
    tags: ['Kitnet', 'Mobiliado', 'Com Wi-Fi'],
    endereco: 'Av. Antônio Frederico Ozanan, 55',
  ),
  const Imovel(
    id: '3',
    titulo: 'Apartamento 2Q — Próx. ao Inatel',
    descricao: 'Apartamento amplo · R\$ 1200/mês',
    preco: 1200,
    posicao: LatLng(-22.2560, -45.7010),
    tipo: TipoListing.moradia,
    tags: ['Apartamento', 'Garagem', 'Perto da Facul'],
    endereco: 'Rua Sete de Setembro, 340',
  ),
  const Imovel(
    id: '4',
    titulo: 'Suíte Individual — Casa de Família',
    descricao: 'Suíte com banheiro privativo · R\$ 550/mês',
    preco: 550,
    posicao: LatLng(-22.2498, -45.6935),
    tipo: TipoListing.moradia,
    tags: ['Suíte', 'Com Wi-Fi'],
    endereco: 'Rua Coronel Joaquim Antônio, 78',
  ),
  const Imovel(
    id: '5',
    titulo: 'República Feminina Girassol',
    descricao: 'Vaga em quarto duplo · R\$ 480/mês',
    preco: 480,
    posicao: LatLng(-22.2535, -45.6960),
    tipo: TipoListing.moradia,
    tags: ['República', 'Mobiliado', 'Perto da Facul', 'Com Wi-Fi'],
    endereco: 'Rua Padre Vitor, 200',
  ),
  const Imovel(
    id: '6',
    titulo: 'Apartamento Studio Moderno',
    descricao: 'Studio novo · R\$ 1500/mês',
    preco: 1500,
    posicao: LatLng(-22.2480, -45.6985),
    tipo: TipoListing.moradia,
    tags: ['Apartamento', 'Mobiliado', 'Garagem', 'Com Wi-Fi'],
    endereco: 'Av. Luiz Dumont Villares, 150',
  ),
  const Imovel(
    id: '7',
    titulo: 'Kitnet Econômica — Centro',
    descricao: 'Kitnet simples · R\$ 400/mês',
    preco: 400,
    posicao: LatLng(-22.2520, -45.6970),
    tipo: TipoListing.moradia,
    tags: ['Kitnet'],
    endereco: 'Rua Major Porphírio, 45',
  ),
  const Imovel(
    id: '8',
    titulo: 'República Masculina Byte House',
    descricao: 'Quarto compartilhado · R\$ 520/mês',
    preco: 520,
    posicao: LatLng(-22.2505, -45.7000),
    tipo: TipoListing.moradia,
    tags: ['República', 'Com Wi-Fi', 'Garagem'],
    endereco: 'Rua Tiradentes, 88',
  ),
  const Imovel(
    id: 'ev1',
    titulo: '🎉 Trote Solidário — INATEL',
    descricao: 'Sábado, 14h · Quadra esportiva',
    preco: 0,
    posicao: LatLng(-22.2555, -45.6945),
    tipo: TipoListing.evento,
    tags: [],
    endereco: 'Campus INATEL',
  ),
  const Imovel(
    id: 'ev2',
    titulo: '🎶 Open Mic Night — Bar do Zé',
    descricao: 'Sexta, 20h · Entrada gratuita',
    preco: 0,
    posicao: LatLng(-22.2515, -45.6965),
    tipo: TipoListing.evento,
    tags: [],
    endereco: 'Praça Getúlio Vargas, 10',
  ),
];
