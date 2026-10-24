import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/linhas_repo.dart';
import '../data/paradas_repo.dart';
import '../domain/models.dart';
import 'planejador.dart';

final paradasRepoProvider = Provider<ParadasRepo>(
  (ref) => ParadasRepo(ref.watch(dadosLocaisProvider)),
);

/// Próximas passagens de uma parada. A tela invalida isto a cada 20 s para atualizar.
///
/// Sem repetição automática: o Riverpod 3 repete provider que falha, com espera crescente, e sem internet
/// a tela ficaria "carregando" por vários segundos em vez de mostrar o erro. A pessoa puxa para atualizar.
final saidasProvider = FutureProvider.autoDispose
    .family<List<SaidasLinha>, ParadaRef>(
      (ref, parada) => ref.watch(paradasRepoProvider).saidas(parada),
      retry: (_, _) => null,
    );

/// Horários, traçados e paradas das linhas, lidos uma vez dos assets.
final dadosLinhasProvider = FutureProvider<DadosLinhas>(
  (ref) => DadosLinhas.carregar(ref.watch(dadosLocaisProvider)),
);
