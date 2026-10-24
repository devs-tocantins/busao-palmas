import 'package:busao_palmas/domain/models.dart';
import 'package:busao_palmas/state/salvos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shopping = Lugar(
  nome: 'Palmas Shopping',
  pos: LatLng(-10.18934, -48.33552),
);
const _uft = Lugar(
  nome: 'UFT',
  detalhe: 'Avenida NS-15',
  pos: LatLng(-10.1784, -48.35956),
);

ProviderContainer _novo() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('casa e trabalho sobrevivem a fechar o app', () async {
    final a = _novo();
    await a.read(salvosProvider.future);
    await a.read(salvosProvider.notifier).definirCasa(_uft);
    await a.read(salvosProvider.notifier).definirTrabalho(_shopping);

    // "Fechar o app": outro container lê do armazenamento.
    final b = _novo();
    final s = await b.read(salvosProvider.future);
    expect(s.casa?.nome, 'UFT');
    expect(s.casa?.detalhe, 'Avenida NS-15');
    expect(s.trabalho?.nome, 'Palmas Shopping');
    expect(s.casa!.pos.latitude, closeTo(-10.1784, 1e-9));
  });

  test('remover casa não mexe no trabalho', () async {
    final c = _novo();
    await c.read(salvosProvider.future);
    final n = c.read(salvosProvider.notifier);
    await n.definirCasa(_uft);
    await n.definirTrabalho(_shopping);
    await n.removerCasa();
    final s = c.read(salvosProvider).value!;
    expect(s.casa, isNull);
    expect(s.trabalho?.nome, 'Palmas Shopping');
  });

  test('recentes: mais novo primeiro, sem repetir e no máximo 8', () async {
    final c = _novo();
    await c.read(salvosProvider.future);
    final n = c.read(salvosProvider.notifier);
    await n.registrarRecente(_uft);
    await n.registrarRecente(_shopping);
    await n.registrarRecente(_uft); // repetido: sobe para o topo, não duplica
    expect(c.read(salvosProvider).value!.recentes.map((l) => l.nome), [
      'UFT',
      'Palmas Shopping',
    ]);

    for (var i = 0; i < 12; i++) {
      await n.registrarRecente(
        Lugar(nome: 'Lugar $i', pos: LatLng(-10.2 - i * 0.01, -48.3)),
      );
    }
    final r = c.read(salvosProvider).value!.recentes;
    expect(r, hasLength(Salvos.maxRecentes));
    expect(r.first.nome, 'Lugar 11');
  });

  test(
    '"Minha localização" e ponto sem nome não entram nos recentes',
    () async {
      final c = _novo();
      await c.read(salvosProvider.future);
      final n = c.read(salvosProvider.notifier);
      await n.registrarRecente(
        const Lugar(
          nome: 'Minha localização',
          pos: LatLng(-10.2, -48.3),
          minhaLocalizacao: true,
        ),
      );
      await n.registrarRecente(
        const Lugar(nome: 'Ponto no mapa', pos: LatLng(-10.2, -48.3)),
      );
      expect(c.read(salvosProvider).value!.recentes, isEmpty);
    },
  );

  test('mesmo nome em lugares distantes são recentes diferentes', () async {
    final c = _novo();
    await c.read(salvosProvider.future);
    final n = c.read(salvosProvider.notifier);
    await n.registrarRecente(
      const Lugar(nome: 'Parada', pos: LatLng(-10.18, -48.33), ehParada: true),
    );
    await n.registrarRecente(
      const Lugar(nome: 'Parada', pos: LatLng(-10.30, -48.31), ehParada: true),
    );
    expect(c.read(salvosProvider).value!.recentes, hasLength(2));
  });

  test('remover recente e limpar tudo', () async {
    final c = _novo();
    await c.read(salvosProvider.future);
    final n = c.read(salvosProvider.notifier);
    await n.registrarRecente(_uft);
    await n.registrarRecente(_shopping);
    await n.removerRecente(_uft);
    expect(c.read(salvosProvider).value!.recentes.map((l) => l.nome), [
      'Palmas Shopping',
    ]);
    await n.limparRecentes();
    expect(c.read(salvosProvider).value!.recentes, isEmpty);
  });

  test('dado corrompido no aparelho não trava o app', () async {
    SharedPreferences.setMockInitialValues({'salvos_v1': '{isso não é json'});
    final s = await _novo().read(salvosProvider.future);
    expect(s.casa, isNull);
    expect(s.recentes, isEmpty);
  });
}
