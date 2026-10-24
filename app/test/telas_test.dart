import 'dart:convert';
import 'dart:io';

import 'package:busao_palmas/core/tema.dart';
import 'package:busao_palmas/data/dados_locais.dart';
import 'package:busao_palmas/data/otp_client.dart';
import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/features/planejar/planejar_page.dart';
import 'package:busao_palmas/features/rota/detalhe_rota_page.dart';
import 'package:busao_palmas/state/planejador.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Estado já com uma rota escolhida, sem rede nem GPS.
class _PlanejadorFalso extends PlanejadorNotifier {
  _PlanejadorFalso(this.inicial);
  final PlanejadorState inicial;

  @override
  PlanejadorState build() => inicial;

  @override
  Future<void> usarMinhaLocalizacao() async {}
}

Future<(PlanejadorState, DadosLocais)> estadoParaTeste({
  bool comRota = true,
}) async {
  final dados = _dados();
  final json = jsonDecode(
    File('test/fixtures/plan.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final grupos = agruparOpcoes(interpretarPlano(json, dados));
  final estado = PlanejadorState(
    origem: const Lugar(
      nome: 'Alameda 19, Quadra 1006 Sul',
      pos: LatLng(-10.2491, -48.3243),
    ),
    destino: const Lugar(
      nome: 'Quadra 405 Norte',
      pos: LatLng(-10.145, -48.342),
    ),
    grupos: AsyncData(grupos),
    selecionado: comRota ? grupos.first : null,
  );
  return (estado, dados);
}

Widget appParaTeste(
  PlanejadorState estado,
  DadosLocais dados,
  Widget tela, {
  Brightness brilho = Brightness.light,
}) {
  return ProviderScope(
    overrides: [
      dadosLocaisProvider.overrideWithValue(dados),
      planejadorProvider.overrideWith(() => _PlanejadorFalso(estado)),
    ],
    child: MaterialApp(
      theme: brilho == Brightness.light ? Tema.claro() : Tema.escuro(),
      home: tela,
    ),
  );
}

void main() {
  testWidgets(
    'detalhe da rota mostra a linha do tempo completa (celular, claro)',
    (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final (estado, dados) = await estadoParaTeste();

      await t.pumpWidget(appParaTeste(estado, dados, const DetalheRotaPage()));
      await t.pump(const Duration(milliseconds: 600));

      expect(tester(t, 'Alameda 19, Quadra 1006 Sul'), isTrue);
      expect(find.textContaining('Caminhe'), findsWidgets);
      expect(find.text('Embarque'), findsWidgets);
      expect(find.text('Desça aqui'), findsWidgets);
      expect(find.textContaining('chega às'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'detalhe da rota no tema escuro e em tela estreita não estoura o layout',
    (t) async {
      t.view.physicalSize = const Size(720, 1280);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      final (estado, dados) = await estadoParaTeste();

      await t.pumpWidget(
        appParaTeste(
          estado,
          dados,
          const DetalheRotaPage(),
          brilho: Brightness.dark,
        ),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('tela de planejamento lista as opções com a sequência da rota', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final (estado, dados) = await estadoParaTeste(comRota: false);

    await t.pumpWidget(appParaTeste(estado, dados, const PlanejarPage()));
    await t.pump(const Duration(milliseconds: 800));

    expect(find.text('Alameda 19, Quadra 1006 Sul'), findsOneWidget);
    expect(find.text('Quadra 405 Norte'), findsOneWidget);
    expect(find.text('Sair agora'), findsOneWidget);
    expect(find.text('Chega primeiro'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sem destino pergunta para onde ir', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      appParaTeste(const PlanejadorState(), _dados(), const PlanejarPage()),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Para onde você quer ir?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

bool tester(WidgetTester t, String texto) =>
    find.text(texto).evaluate().isNotEmpty;
