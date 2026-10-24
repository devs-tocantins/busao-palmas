import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/data/busca_local.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

dynamic _json(String n) =>
    jsonDecode(File('assets/data/$n.json').readAsStringSync());

BuscaLocal _busca() {
  Color cor(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));
  final dados = DadosLocais(
    [
      for (final x in _json('paradas') as List)
        ParadaLocal(
          x['id'] as int,
          x['nome'] as String,
          LatLng((x['lat'] as num).toDouble(), (x['lng'] as num).toDouble()),
        ),
    ],
    {
      for (final x in _json('linhas') as List)
        x['numero'] as String: LinhaLocal(
          x['numero'] as String,
          x['nome'] as String,
          cor(x['cor'] as String),
          cor(x['corTexto'] as String),
        ),
    },
  );
  return BuscaLocal(
    dados,
    _json('busca') as List,
    _json('apelidos') as Map<String, dynamic>,
  );
}

List<String> _titulos(List<ResultadoBusca> r) => [for (final x in r) x.titulo];

void main() {
  test('semAcento mantém maiúsculas e tira só os acentos', () {
    expect(semAcento('Rodoviária de Palmas'), 'Rodoviaria de Palmas');
    expect(semAcento('AÇÃO'), 'ACAO');
    expect(semAcento('Teotônio'), 'Teotonio');
  });

  test('normalizar: avenida, quadras e siglas de rua', () {
    expect(normalizar('Av. NS-10'), 'avenida ns 10');
    expect(normalizar('Quadra 104  Sul'), 'quadra 104 sul');
    expect(normalizar('LO 04'), 'lo 4');
  });

  final b = _busca();

  test('acento não muda o resultado (o defeito que o servidor tinha)', () {
    expect(_titulos(b.buscar('rodoviária')), _titulos(b.buscar('rodoviaria')));
    expect(_titulos(b.buscar('rodoviária')).first, contains('Rodoviária'));
  });

  test('responde com 1 ou 2 letras', () {
    expect(b.buscar('u'), isNotEmpty);
    expect(b.buscar('uf'), isNotEmpty);
  });

  test('apelido: uft acha a universidade em primeiro', () {
    expect(
      _titulos(b.buscar('uft')).first,
      'Universidade Federal do Tocantins',
    );
  });

  test('palmas shopping: o shopping vem antes de avenidas e paradas', () {
    expect(_titulos(b.buscar('palmas shopping')).first, 'Palmas Shopping');
  });

  test('número da linha acha a linha, mesmo sem o zero da frente', () {
    final r = b.buscar('90');
    expect(r.first.tipo, TipoBusca.linha);
    expect(r.first.linha, '090');
    expect(b.buscar('090').first.linha, '090');
    expect(b.buscar('620').first.linha, '620');
  });

  test('nome da linha também acha a linha', () {
    final r = b.buscar('corujão');
    expect(r.any((x) => x.tipo == TipoBusca.linha && x.linha == '620'), isTrue);
  });

  test('paradas aparecem com o tipo certo e no máximo 3', () {
    final r = b.buscar('104 sul', limite: 20);
    expect(
      r.where((x) => x.tipo == TipoBusca.parada).length,
      lessThanOrEqualTo(3),
    );
    expect(r.first.lugar, isNotNull);
  });

  test('perto: de dois lugares iguais, o mais próximo vem antes', () {
    const prefeitura = LatLng(-10.1845, -48.3336);
    final r = b.buscar('prefeitura', perto: prefeitura);
    expect(r, isNotEmpty);
    expect(r.first.titulo, contains('Prefeitura'));
  });

  test('texto sem sentido não devolve nada nem quebra', () {
    expect(b.buscar('zzzzqq'), isEmpty);
    expect(b.buscar('   '), isEmpty);
    expect(b.buscar('!!!'), isEmpty);
  });
}
