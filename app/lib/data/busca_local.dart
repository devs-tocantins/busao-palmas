import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';
import 'dados_locais.dart';

const _acentos = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Tira os acentos e mantém o resto. O geocodificador do Bus2 acerta "rodoviaria" e erra "rodoviária".
String semAcento(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final minusculo = c.toLowerCase();
    final t = _acentos[minusculo];
    b.write(t == null ? c : (c == minusculo ? t : t.toUpperCase()));
  }
  return b.toString();
}

/// Texto comparável: sem acento, minúsculo, "av" vira "avenida", "ns-10" vira "ns 10".
/// Mesma regra de tools/indice-busca.mjs.
String normalizar(String s) {
  var t = semAcento(s).toLowerCase();
  t = t.replaceAll(RegExp(r'\bav\b\.?'), 'avenida');
  t = t.replaceAll(RegExp(r'\bq[ds]?\b\.?'), 'quadra');
  t = t.replaceAll(RegExp(r'\bqd\b'), 'quadra');
  t = t.replaceAllMapped(
    RegExp(r'\b(ns|lo|se|ne|so|no)[-\s]?0*(\d+)\b'),
    (m) => '${m[1]} ${m[2]}',
  );
  return t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

enum TipoBusca { linha, parada, lugar }

/// Um resultado da busca local: linha, parada ou lugar do índice.
class ResultadoBusca {
  const ResultadoBusca({
    required this.tipo,
    required this.titulo,
    this.detalhe,
    this.pos,
    this.linha,
    this.categoria,
    this.pontos = 0,
  });

  final TipoBusca tipo;
  final String titulo;
  final String? detalhe;
  final LatLng? pos;

  /// Número da linha, quando [tipo] é linha.
  final String? linha;

  /// `aeroporto`, `educacao`, `saude`, `comercio`, `lazer`, `culto`, `bairro`, `rua` ou `lugar`.
  final String? categoria;

  /// Quanto menor, melhor.
  final double pontos;

  Lugar? get lugar => pos == null
      ? null
      : Lugar(
          nome: titulo,
          detalhe: detalhe,
          pos: pos!,
          ehParada: tipo == TipoBusca.parada,
        );
}

const _nomeCategoria = {
  'aeroporto': 'Aeroporto',
  'educacao': 'Educação',
  'saude': 'Saúde',
  'comercio': 'Comércio',
  'lazer': 'Lazer',
  'culto': 'Igreja',
  'bairro': 'Bairro',
  'rua': 'Rua',
  'lugar': 'Lugar',
};

const _pesoCategoria = {
  'aeroporto': 0,
  'educacao': 1,
  'saude': 1,
  'lazer': 1,
  'bairro': 1,
  'comercio': 2,
  'lugar': 2,
  'culto': 3,
  'rua': 3,
};

class _Item {
  _Item(this.nome, this.palavras, this.categoria, this.pos);
  final String nome;
  final List<String> palavras;
  final String categoria;
  final LatLng pos;
}

/// Busca de lugares, paradas e linhas no aparelho: responde a cada letra, sem internet e sem acento.
/// Os lugares vêm de assets/data/busca.json; os apelidos ("uft") de assets/data/apelidos.json.
class BuscaLocal {
  BuscaLocal(this._dados, List indice, Map<String, dynamic> apelidos)
    : _apelidos = {
        for (final e in apelidos.entries) normalizar(e.key): e.value as String,
      },
      _itens = [
        for (final x in indice)
          _Item(
            x['n'] as String,
            normalizar(x['n'] as String).split(' '),
            x['k'] as String,
            LatLng((x['la'] as num).toDouble(), (x['lo'] as num).toDouble()),
          ),
      ] {
    for (final p in _dados.paradas) {
      // Paradas sem nome de verdade ("Parada 37763650") não adiantam na busca.
      if (p.nome.startsWith('Parada ')) continue;
      _paradas.add(
        _Item(p.nome, normalizar(p.nome).split(' '), 'parada', p.pos),
      );
    }
  }

  static Future<BuscaLocal> carregar(DadosLocais dados) async {
    final indice = jsonDecode(
      await rootBundle.loadString('assets/data/busca.json'),
    ) as List;
    final apelidos = jsonDecode(
      await rootBundle.loadString('assets/data/apelidos.json'),
    ) as Map<String, dynamic>;
    return BuscaLocal(dados, indice, apelidos);
  }

  final DadosLocais _dados;
  final Map<String, String> _apelidos;
  final List<_Item> _itens;
  final List<_Item> _paradas = [];

  static bool _bate(List<String> termos, List<String> palavras) =>
      termos.every((t) => palavras.any((w) => w.startsWith(t)));

  /// Resultados para [consulta], do melhor para o pior. [perto] (a posição da pessoa) desempata por distância.
  List<ResultadoBusca> buscar(
    String consulta, {
    LatLng? perto,
    int limite = 8,
  }) {
    final normal = normalizar(consulta);
    if (normal.isEmpty) return const [];
    final termos = normalizar(_apelidos[normal] ?? normal)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    if (termos.isEmpty) return const [];
    const dist = Distance();
    double longe(LatLng p) => perto == null
        ? 0
        : (dist.as(LengthUnit.Meter, perto, p) / 1000).clamp(0, 10) * 0.2;

    final saida = <ResultadoBusca>[];

    // Linhas: só números ("90" acha 090) ou palavras do nome ("eixão").
    final soNumero = termos.length == 1 && RegExp(r'^\d+$').hasMatch(termos[0]);
    for (final l in _dados.linhas.values) {
      final numeroBate =
          soNumero &&
          l.numero
              .replaceFirst(RegExp(r'^0+'), '')
              .startsWith(termos[0].replaceFirst(RegExp(r'^0+'), '')) &&
          termos[0].replaceFirst(RegExp(r'^0+'), '').isNotEmpty;
      final numeroExato = soNumero && l.numero == termos[0];
      final nomeBate =
          !soNumero && _bate(termos, normalizar(l.nome).split(' '));
      if (numeroBate || numeroExato || nomeBate) {
        saida.add(
          ResultadoBusca(
            tipo: TipoBusca.linha,
            titulo: l.nome,
            linha: l.numero,
            pontos: numeroExato ? -10 : (numeroBate ? -5 : 4),
          ),
        );
      }
    }

    final vistos = <String>{};
    var paradas = 0;
    for (final i in _paradas) {
      if (paradas >= 3) break;
      if (!_bate(termos, i.palavras)) continue;
      paradas++;
      saida.add(
        ResultadoBusca(
          tipo: TipoBusca.parada,
          titulo: i.nome,
          detalhe: 'Parada de ônibus',
          pos: i.pos,
          categoria: 'parada',
          pontos:
              (i.palavras.first.startsWith(termos[0]) ? 0 : 5) +
              2.5 +
              longe(i.pos),
        ),
      );
    }
    for (final i in _itens) {
      if (!_bate(termos, i.palavras)) continue;
      final chave =
          '${i.palavras.join(' ')}|${(i.pos.latitude * 200).round()}|${(i.pos.longitude * 200).round()}';
      if (!vistos.add(chave)) continue;
      saida.add(
        ResultadoBusca(
          tipo: TipoBusca.lugar,
          titulo: i.nome,
          detalhe: _nomeCategoria[i.categoria],
          pos: i.pos,
          categoria: i.categoria,
          pontos:
              (i.palavras.first.startsWith(termos[0]) ? 0 : 5) +
              (_pesoCategoria[i.categoria] ?? 3) +
              i.nome.length / 100 +
              longe(i.pos),
        ),
      );
    }
    saida.sort((a, b) => a.pontos.compareTo(b.pontos));
    return saida.take(limite).toList();
  }
}
