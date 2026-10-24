import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/formato.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/otp_client.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

DadosLocais _dados() {
  final p =
      jsonDecode(File('assets/data/paradas.json').readAsStringSync()) as List;
  final l =
      jsonDecode(File('assets/data/linhas.json').readAsStringSync()) as List;
  Color cor(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));
  return DadosLocais(
    [
      for (final x in p)
        ParadaLocal(
          x['id'] as int,
          x['nome'] as String,
          LatLng((x['lat'] as num).toDouble(), (x['lng'] as num).toDouble()),
        ),
    ],
    {
      for (final x in l)
        x['numero'] as String: LinhaLocal(
          x['numero'] as String,
          x['nome'] as String,
          cor(x['cor'] as String),
          cor(x['corTexto'] as String),
        ),
    },
  );
}

void main() {
  final json = jsonDecode(
    File('test/fixtures/plan.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('interpreta uma resposta real do planejador de Palmas', () {
    final opcoes = interpretarPlano(json, _dados());
    expect(opcoes, hasLength(5));
    for (final o in opcoes) {
      expect(o.trechos.first.tipo, TipoTrecho.andar);
      expect(o.trechos.where((t) => t.tipo == TipoTrecho.onibus), isNotEmpty);
      expect(o.fim.isAfter(o.inicio), isTrue);
    }
    final bus = opcoes.first.onibus.first;
    expect(bus.linha, isNotNull);
    expect(
      bus.cor,
      isNotNull,
      reason: 'a cor vem do linhas.json; o planejador não manda cor',
    );
    expect(bus.caminho.length, greaterThan(2));
    expect(bus.numParadas, greaterThan(0));
  });

  test('nomes de parada legíveis em vez de códigos numéricos', () {
    final opcoes = interpretarPlano(json, _dados());
    for (final o in opcoes) {
      for (final b in o.onibus) {
        expect(RegExp(r'^\d+$').hasMatch(b.nomeDe), isFalse, reason: b.nomeDe);
        expect(
          RegExp(r'^\d+$').hasMatch(b.nomePara),
          isFalse,
          reason: b.nomePara,
        );
      }
    }
  });

  test('agrupa opções que embarcam e descem nas mesmas paradas', () {
    final opcoes = interpretarPlano(json, _dados());
    final grupos = agruparOpcoes(opcoes);
    expect(grupos.length, lessThanOrEqualTo(opcoes.length));
    expect(grupos.fold<int>(0, (s, g) => s + g.todas.length), opcoes.length);
    for (final g in grupos) {
      for (final alt in g.alternativas) {
        expect(alt.chave, g.principal.chave);
        expect(alt.fim.isBefore(g.principal.fim), isFalse);
      }
    }
  });

  test('formatação de tempo e distância', () {
    expect(duracaoTexto(const Duration(minutes: 49)), '49 min');
    expect(duracaoTexto(const Duration(minutes: 68)), '1 h 8 min');
    expect(duracaoTexto(const Duration(minutes: 120)), '2 h');
    expect(distanciaTexto(630), '630 m');
    expect(distanciaTexto(1240), '1,2 km');
    // 21:00 UTC é 18:00 em Palmas (UTC-3).
    expect(horaPalmas(DateTime.utc(2026, 10, 26, 21)), '18:00');
  });

  test('sem itinerários vira SemRota', () {
    expect(
      () => interpretarPlano({
        'plan': {'itineraries': []},
      }, _dados()),
      throwsA(isA<SemRota>()),
    );
    expect(
      () => interpretarPlano({
        'error': {'msg': 'x'},
      }, _dados()),
      throwsA(isA<SemRota>()),
    );
  });
}
