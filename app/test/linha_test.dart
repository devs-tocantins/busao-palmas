import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/tema.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/linhas_repo.dart';
import 'package:busao_palmas/features/linha/linha_page.dart';
import 'package:busao_palmas/features/linha/linhas_page.dart';
import 'package:busao_palmas/data/frota_repo.dart';
import 'package:busao_palmas/state/frota.dart';
import 'package:busao_palmas/state/mapa.dart';
import 'package:busao_palmas/state/parada.dart';
import 'package:busao_palmas/data/paradas_repo.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/state/planejador.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

dynamic _json(String n) =>
    jsonDecode(File('assets/data/$n.json').readAsStringSync());

DadosLocais _dados() {
  Color cor(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));
  return DadosLocais(
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
}

DadosLinhas _linhas() => DadosLinhas.montar(
  linhas: _json('linhas') as List,
  horarios: _json('horarios') as Map,
  trajetos: _json('trajetos') as Map,
  dados: _dados(),
);

Future<void> _abrir(WidgetTester t, Widget tela) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => tela),
      GoRoute(
        path: '/linha/:numero',
        builder: (_, s) =>
            Scaffold(body: Text('LINHA ${s.pathParameters['numero']}')),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        dadosLocaisProvider.overrideWithValue(_dados()),
        dadosLinhasProvider.overrideWith((ref) async => _linhas()),
        estiloMapaProvider.overrideWith((ref, escuro) async => null),
        frotaProvider.overrideWith((ref) => Stream.value(const <Onibus>[])),
      ],
      child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
    ),
  );
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  testesParadaPerto();
  testesTelaParadaPerto();
  test('monta as 47 linhas com horários, traçado e paradas', () {
    final d = _linhas();
    expect(d.porNumero.length, 47);
    final coruja = d.porNumero['620']!;
    expect(coruja.sentidos.length, 2);
    for (final s in coruja.sentidos) {
      expect(s.caminho.length, greaterThan(10));
      expect(s.paradas.length, greaterThan(50));
      expect(
        s.servicos.map((x) => x.nome),
        containsAll(['Dias úteis', 'Sábados', 'Domingos']),
      );
    }
    expect(coruja.sentidos[0].servicos.first.saidas, ['00:30', '02:30']);
    expect(
      d.todas.first.linha.numero.compareTo(d.todas.last.linha.numero),
      lessThan(0),
    );
  });

  test('toda linha tem ao menos um sentido com horário e paradas', () {
    for (final l in _linhas().todas) {
      expect(l.sentidos, isNotEmpty, reason: l.linha.numero);
      expect(
        l.sentidos.every((s) => s.paradas.isNotEmpty && s.servicos.isNotEmpty),
        isTrue,
        reason: l.linha.numero,
      );
    }
  });

  test('hoje: domingo é 0 e sábado é 6, no relógio de Palmas', () {
    // 2026-10-25 é domingo; 02:00 UTC ainda é sábado em Palmas (UTC-3).
    expect(DadosLinhas.hoje(DateTime.utc(2026, 10, 25, 12)), 0);
    expect(DadosLinhas.hoje(DateTime.utc(2026, 10, 25, 2)), 6);
    expect(DadosLinhas.hoje(DateTime.utc(2026, 10, 26, 12)), 1);
  });

  testWidgets('tela da linha: nome, sentidos, horários e paradas', (t) async {
    await _abrir(t, const LinhaPage(numero: '620'));
    expect(find.text('Linha 620'), findsOneWidget);
    expect(find.text('Corujão - Sol Nascente / 603 Norte'), findsOneWidget);
    expect(find.textContaining('Sentido 603 Norte'), findsOneWidget);
    expect(find.text('Horários'), findsOneWidget);
    expect(find.text('Dias úteis'), findsOneWidget);
    expect(find.textContaining('Paradas ('), findsOneWidget);
    // Um tipo de dia que não é o de hoje (o teste não depende do dia em que roda).
    final outro = DadosLinhas.hoje() == 0 ? 'Sábados' : 'Domingos';
    await t.tap(find.text(outro));
    await t.pump();
    expect(find.text('Horários de ${outro.toLowerCase()}.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('linha que não existe avisa', (t) async {
    await _abrir(t, const LinhaPage(numero: '999'));
    expect(find.text('Linha não encontrada.'), findsOneWidget);
  });

  testWidgets('aba Linhas lista, filtra por número e abre a linha', (t) async {
    await _abrir(t, const LinhasPage());
    expect(find.byType(ListTile), findsWidgets);
    await t.enterText(find.byType(TextField), 'corujao');
    await t.pump();
    expect(find.text('620'), findsOneWidget);
    expect(find.text('090'), findsNothing);
    await t.tap(find.text('620'));
    await t.pumpAndSettle();
    expect(find.text('LINHA 620'), findsOneWidget);
  });
}

void testesParadaPerto() {
  test('maisPerto: acha a parada do sentido mais próxima do ponto', () {
    final s = _linhas().porNumero['620']!.sentidos.first;
    final alvo = s.paradas[10].pos;
    final r = s.maisPerto(alvo)!;
    expect(r.indice, 10);
    expect(r.metros, lessThan(1));
    // Um ponto ~50 m ao lado continua apontando para a mesma parada, a poucas dezenas de metros.
    final aoLado = LatLng(alvo.latitude + 0.00045, alvo.longitude);
    final r2 = s.maisPerto(aoLado)!;
    expect(r2.indice, 10);
    expect(r2.metros, inInclusiveRange(40, 60));
  });
}

class _PlanejadorComLocal extends PlanejadorNotifier {
  _PlanejadorComLocal(this.pos);
  final LatLng? pos;

  @override
  PlanejadorState build() => PlanejadorState(minhaPos: pos);

  @override
  Future<void> usarMinhaLocalizacao() async {}
}

Future<void> _abrirComLocal(WidgetTester t, LatLng? pos) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const LinhaPage(numero: '620'),
      ),
      GoRoute(
        path: '/parada',
        builder: (_, _) => const Scaffold(body: Text('PARADA')),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        dadosLocaisProvider.overrideWithValue(_dados()),
        dadosLinhasProvider.overrideWith((ref) async => _linhas()),
        estiloMapaProvider.overrideWith((ref, escuro) async => null),
        frotaProvider.overrideWith((ref) => Stream.value(const <Onibus>[])),
        planejadorProvider.overrideWith(() => _PlanejadorComLocal(pos)),
        paradasRepoProvider.overrideWithValue(_RepoVazio()),
      ],
      child: MaterialApp.router(theme: Tema.claro(), routerConfig: router),
    ),
  );
  await t.pump(const Duration(milliseconds: 600));
}

class _RepoVazio extends ParadasRepo {
  _RepoVazio() : super(_dados());
  @override
  Future<List<SaidasLinha>> saidas(ParadaRef parada) async => const [];
}

void testesTelaParadaPerto() {
  testWidgets('sem localização, oferece achar a parada mais perto', (t) async {
    await _abrirComLocal(t, null);
    expect(find.text('Qual parada fica mais perto de mim?'), findsOneWidget);
    expect(find.textContaining('Parada mais perto de você'), findsNothing);
  });

  testWidgets(
    'com localização, mostra a parada da linha mais perto e a destaca na lista',
    (t) async {
      final s = _linhas().porNumero['620']!.sentidos.first;
      await _abrirComLocal(t, s.paradas[3].pos);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Parada mais perto de você'), findsOneWidget);
      expect(
        find.text('Sem passagem desta linha nas próximas horas'),
        findsOneWidget,
      );
      await t.tap(find.textContaining('Parada mais perto de você'));
      await t.pumpAndSettle();
      expect(find.text('PARADA'), findsOneWidget);
    },
  );
}
