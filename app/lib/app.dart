import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/tema.dart';
import 'features/planejar/busca_page.dart';
import 'features/planejar/planejar_page.dart';
import 'features/rota/detalhe_rota_page.dart';
import 'state/planejador.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const PlanejarPage()),
    GoRoute(
      path: '/busca/:campo',
      builder: (_, s) => BuscaPage(
        campo: s.pathParameters['campo'] == 'origem'
            ? CampoMapa.origem
            : CampoMapa.destino,
      ),
    ),
    GoRoute(path: '/rota', builder: (_, _) => const DetalheRotaPage()),
  ],
);

class BusaoPalmasApp extends StatelessWidget {
  const BusaoPalmasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Config.nomeApp,
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.escuro(),
      routerConfig: _router,
    );
  }
}
