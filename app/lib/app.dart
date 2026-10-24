import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'core/config.dart';
import 'core/layout.dart';
import 'core/tema.dart';
import 'domain/models.dart';
import 'features/inicio/inicio_page.dart';
import 'features/linha/linha_page.dart';
import 'features/linha/linhas_page.dart';
import 'features/mais/mais_page.dart';
import 'features/parada/parada_page.dart';
import 'features/planejar/busca_page.dart';
import 'features/planejar/planejar_page.dart';
import 'features/rota/detalhe_rota_page.dart';

/// Abas de baixo: Início, Mapa, Linhas e Mais. As demais telas abrem por cima delas.
final _router = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => _Abas(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const ColunaCentral(child: InicioPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/mapa', builder: (_, _) => const PlanejarPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/linhas',
              builder: (_, _) => const ColunaCentral(child: LinhasPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mais',
              builder: (_, _) => const ColunaCentral(child: MaisPage()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/busca/:campo',
      builder: (_, s) => ColunaCentral(
        child: BuscaPage(modo: ModoBusca.doTexto(s.pathParameters['campo'])),
      ),
    ),
    GoRoute(
      path: '/linha/:numero',
      builder: (_, s) => ColunaCentral(
        child: LinhaPage(numero: s.pathParameters['numero'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/rota',
      builder: (_, _) => const ColunaCentral(child: DetalheRotaPage()),
    ),
    GoRoute(
      path: '/parada',
      builder: (_, s) {
        final q = s.uri.queryParameters;
        final la = double.tryParse(q['lat'] ?? ''),
            lo = double.tryParse(q['lng'] ?? '');
        if (la == null || lo == null) {
          return const ColunaCentral(child: InicioPage());
        }
        return ColunaCentral(
          child: ParadaPage(
            parada: ParadaRef(nome: q['nome'] ?? 'Parada', pos: LatLng(la, lo)),
          ),
        );
      },
    ),
  ],
);

class _Abas extends StatelessWidget {
  const _Abas({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    // Voltar numa aba que não é o Início leva ao Início, e só dali o app fecha.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (voltou, _) {
        if (!voltou) shell.goBranch(0);
      },
      child: telaGrande(context)
          ? Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: shell.currentIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => shell.goBranch(
                      i,
                      initialLocation: i == shell.currentIndex,
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Início'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map_rounded),
                        label: Text('Mapa'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.route_outlined),
                        selectedIcon: Icon(Icons.route_rounded),
                        label: Text('Linhas'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.more_horiz_rounded),
                        label: Text('Mais'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: shell),
                ],
              ),
            )
          : Scaffold(
              body: shell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: shell.currentIndex,
                // Tocar na aba em que já está volta ao começo dela.
                onDestinationSelected: (i) =>
                    shell.goBranch(i, initialLocation: i == shell.currentIndex),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Início',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map_rounded),
                    label: 'Mapa',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.route_outlined),
                    selectedIcon: Icon(Icons.route_rounded),
                    label: 'Linhas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'Mais',
                  ),
                ],
              ),
            ),
    );
  }
}

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
