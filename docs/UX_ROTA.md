# Rota "de onde para onde"

Primeira funcionalidade a ficar perfeita: escolher origem e destino no mapa e ver o que andar a pé,
quais ônibus pegar, onde trocar e quais ônibus são equivalentes.
Referência de interface: Moovit (prints de 2026-10-23, guardados só localmente em `pesquisa/moovit/`, fora do repositório). Só o padrão de uso; visual e textos são nossos.

## Fluxo

1. **Pontos.** Origem começa em "Minha localização". Destino: tocar no mapa, arrastar o pino ou buscar por nome.
   A rota calcula assim que o destino existe (o Moovit exige um botão "Encontrar rotas").
2. **Resultados.** Painel sobre o mapa, uma opção por cartão: duração grande, "Sai 21:54 (em 3 min) · chega 22:16",
   sequência `andar 7 › 180 › 040 › andar 9`. Atalhos "Menos trocas" e "Menos caminhada". Mapa mostra a opção selecionada.
3. **Detalhe.** Linha do tempo vertical, um bloco por trecho:
   - A pé: distância e minutos ("630 m · 7 min").
   - Parada de embarque: nome legível, acessibilidade, foto da parada se houver.
   - Ônibus: número, sentido, próximas saídas ("em 15 min · 21:54 · 22:14"), "ao vivo" ou "horário programado", quantas paradas e minutos de viagem.
   - Parada de desembarque; se houver troca, a espera ("troca de 4 min").
   - Chegada ao destino.
4. **Alternativas equivalentes.** Opções que embarcam e descem nas mesmas paradas viram um só cartão ("180 ou 190").
   No detalhe, "Mostrar mais opções" lista cada ônibus equivalente com suas próximas saídas (como o Moovit faz dentro do passo).
5. **Aviso de chegada** por trecho de ônibus (botão no passo).
6. Ajustar a saída: "Sair agora", antes/depois, ou escolher horário.

## O que copiar e o que não copiar do Moovit

Copiar: sequência em ícones no cartão; duração e horário de chegada no topo; linha do tempo com trechos expansíveis;
"ao vivo" separado de "programado"; "mostrar mais opções" para ônibus equivalentes; ícone de acessibilidade na parada.

Não copiar: propaganda no meio da lista e do detalhe, cartão do Uber, CO₂, "dicas", botão de pagamento,
campo de destino cortado, textos como "Sai em 3, 23, 21:54".

## Dados (verificado 2026-10-23)

O OTP de Palmas (`…/otp/routers/default/plan`, `numItineraries=5`) devolve, por opção: trechos `WALK`/`BUS` com
distância, duração, traçado (polyline) e passos da caminhada; para ônibus, número, sentido, cor, `tripId`,
`realTime` e atrasos; totais de caminhada, trânsito e trocas. Teste sul→norte: opções com 1 e 2 trocas.
Não comparado com o resultado do Moovit (coordenadas e hora diferentes).

## Riscos

- **Nome das paradas:** resolvido em 85% (ver [ARQUITETURA](ARQUITETURA.md)); 15% ficam como "Parada <código>" até a comunidade corrigir.
  O Moovit mostra "Ponto Nº 0208 Q. 1004 Sul Avenida Ns 4"; a nossa fonte não tem esse número. Foto da parada: sem fonte.
- **Busca por lugar:** resolvida com índice próprio (ver [ARQUITETURA](ARQUITETURA.md)). Limite: só acha o que está no OpenStreetMap.
- **Qualidade do plano:** validar com trajetos que a população conhece antes de confiar.
- **Alternativas equivalentes:** o OTP devolve opções separadas; agrupar por (parada de embarque, parada de desembarque) é lógica nossa.

## Visual

Estilo Uber: fundo claro, preto e branco, botão primário preto, cantos bem arredondados, tipografia grande, mapa sóbrio.
Linhas usam `routeColor` da API (hoje todas `#007CBA`). Amarelo de Palmas `#FFD100` e cores da bandeira do Tocantins
só como detalhe secundário (valores oficiais da bandeira: não verificados). Contraste mínimo 4,5:1, alvo de toque ≥ 48 px.

## Em aberto

- Foto da parada.
- Plano de rota validado em trajetos reais.
