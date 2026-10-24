# Moovit em 10 partes: o que temos e o que falta

Serve para decidir a ordem do que construir depois do M2. Complementa [TELAS_E_PLANO.md](TELAS_E_PLANO.md), que diz quais telas existem; aqui o foco é a **qualidade de uso** de cada parte.

Estado do app em 2026-10-25 (conferido no código e no navegador). O que o Moovit faz vem do uso do app, não de documentação oficial: tratar como referência, não como especificação. Onde o SOU diverge, vale o SOU.

## Defeitos confirmados hoje

**Busca de lugar** (`busca_page.dart`, `otp_client.dart`):
1. **Acento quebra a busca.** O geocodificador responde `rodoviaria` com a Rodoviária de Palmas e `rodoviária` com rodovias (testado). O app manda o texto como foi digitado.
2. **Nada aparece antes de 3 letras** e cada tecla espera a rede. `busca.json` (2.962 lugares) e `apelidos.json` existem desde o M1, mas o app não os usa.
3. **A ordem é a do servidor.** Em `palmas shopping`, o shopping é o 3º, atrás de avenida e parada. Em `taquaralto` o bairro não aparece.
4. **Linhas não são buscáveis** na caixa de busca; todos os resultados têm o mesmo ícone; não há distância até o resultado.

**Computador** (testado em 800×600 e pelo código):
1. **O painel de baixo não arrasta com o mouse** (o Flutter não aceita arrastar com mouse em listas por padrão). Ele ocupa metade da tela e o mapa fica numa faixa.
2. **Sem botões de zoom e sem "minha localização".** A roda do mouse dá zoom, mas ninguém descobre.
3. A tela é a do celular esticada: cartões de 1.000 px de largura, sem coluna lateral.

## As 10 partes

Prioridade: **P0** = defeito confirmado ou bloqueia o uso; **P1** = diferença que o morador sente; **P2** = depois.

| # | Parte | O que o Moovit faz | O que temos | Falta | Prio |
|---|---|---|---|---|---|
| 1 | **Início** | Busca no topo, casa e trabalho, paradas e linhas perto com tempo real, mapa por trás | Busca, casa/trabalho, favoritos, "perto de você" (3 paradas, 600 m), recentes | Linhas perto (não só paradas); abrir direto na parada de um toque; atualizar sozinho | P1 |
| 2 | **Busca** | Resultado a cada letra; mistura lugar, parada e linha; corrige acento e erro de digitação; ícone por tipo | Só geocodificador, 3+ letras, ordem do servidor | Ver defeitos acima. Índice local + servidor, acento, ranking, linhas, ícone e distância | **P0** |
| 3 | **Mapa** | Zoom, "minha localização", paradas no mapa (toque abre a parada), ônibus ao vivo, rotas desenhadas | Mapa limpo, pinos, rota; paradas no mapa com zoom ≥ 15 (toque abre a parada); botões de zoom e localização em tela grande | Botão de localização no celular; ônibus ao vivo no mapa | P1 |
| 4 | **Planejar viagem** | Sair agora, sair às, **chegar às**, filtros (menos trocas, menos caminhada, acessível) | Sair agora, sair às, chegar às; 5 opções agrupadas; "próximo ônibus" quando não há agora | Filtros de trocas e caminhada | P2 |
| 5 | **Detalhe e acompanhamento** | Linha do tempo, mapa do trecho, "avisar para descer", acompanhar em tempo real | Linha do tempo, mapa, toque abre a parada | Acompanhar viagem e aviso para descer (exige GPS em segundo plano; só Android) | P2 |
| 6 | **Parada** | Próximos ônibus ao vivo, grade do dia, linhas que passam, favoritar, avisos | Próximos ao vivo (20 s), "depois", estrela, "como chegar aqui" | Grade do dia por linha; lista das linhas que passam (`paradas.json` já traz `linhas`); mapa da parada | P1 |
| 7 | **Linhas** | Lista, percurso, paradas, horários, ônibus ao vivo no mapa | Lista com busca, percurso, paradas, horários por dia, parada mais perto de você | Linhas com 2+ variantes de percurso | P1 |
| 8 | **Favoritos e salvos** | Casa, trabalho, paradas, linhas, rotas salvas, tudo numa aba | Casa, trabalho, recentes, estrela em linha e parada (aparecem no Início) | Rota favorita (A→B em um toque); gerenciar favoritos num só lugar | P2 |
| 9 | **Tempo real e avisos** | Ao vivo e atraso em toda parte; avisos de serviço; notificação de chegada | Ônibus ao vivo no mapa, na linha e na rota; "seu ônibus" com tempo e distância; atraso na parada | Ao vivo na web (exige proxy); avisos (`alerts` está vazio em Palmas); notificação com app fechado exige servidor | P1 |
| 10 | **Plataforma e experiência** | Layout próprio para tela grande, offline, acessibilidade, primeira abertura, ajustes, compartilhar | Funciona em Android e web; dados de linhas e horários embutidos (funcionam sem internet) | Layout de computador; primeira abertura (explicar a localização); tema e tamanho de letra em "Mais"; botão compartilhar rota/parada (o link já existe) | **P0** (computador), P1 (resto) |

## Ordem proposta

1. **Busca** (parte 2): é a porta de entrada de tudo. Índice local + servidor, acento, ranking, linhas e paradas.
2. **Computador e mapa** (partes 3 e 10): painel lateral em tela larga, botões de zoom e localização.
3. ~~Paradas no mapa e "chegar às"~~ (feito em 2026-10-25).
4. **Parada completa** (parte 6): grade do dia e linhas que passam.
5. ~~Ao vivo no mapa, na linha e "seu ônibus" na rota~~ (feito em 2026-10-24; só no app). Falta testar no celular e decidir o proxy para a web.

Não verificado: ônibus ao vivo no celular (testado só a API e a tela em teste automático); formato de `alerts` com conteúdo; se o SOU mostra as mesmas 47 linhas (conferência pendente).
