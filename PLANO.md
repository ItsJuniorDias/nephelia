# Plano de tarefas: Nephelia

Uma tarefa por vez, em primeiro plano. Cada tarefa termina com os testes passando
(`tests/`), o jogo rodando no Mac e um commit. Marcar `[x]` ao concluir.

**O jogo (decidido em 2026-09-22):** arena de tiro frenética nos céus. Partidas rápidas de
todos contra todos, com 4 a 6 jogadores, em ilhas flutuantes ligadas por trilhos aéreos, com
poderes. O visual é uma cidade flutuante do começo do século XX. Ordem dos modos:
**bots → multiplayer na mesma Wi-Fi → online** (bots completando vagas).

## Já feito
- [x] Projeto Godot 4.7.2 (renderizador Mobile, física Jolt), Git iniciado, Input Map
- [x] Jogador em primeira pessoa + controles de toque + fase de teste + 15 testes automáticos
- [x] Preset de exportação iOS
- [x] Curadoria de assets gratuitos + download dos 12 pacotes (ver `CREDITS.md`)

## Tarefa 0: Arrumação
- [x] Trocar a cena principal para `res://levels/skyplaza/skyplaza.tscn` (feito na tarefa 7; reabrir o Godot)
- [x] Primeiro commit (`02aaa5a`)
- [ ] Push para o GitHub: criar o repositório privado `nephelia` na conta ItsJuniorDias (remoto SSH já configurado)
- [x] Confirmar que o jogo abre no iPhone 15
- [x] Filtros de exportação no preset iOS (`tests/*`, `tools/*`, animações e o FBX de origem)

---

## Marco 1: arena contra bots (offline)
Meta: partida de 5 minutos, você contra 3 a 5 bots, numa arena de ilhas com trilhos
aéreos, a 60 FPS no iPhone.

### 1. Controladores (base para bots e rede): [x] feito
- O jogador passa a receber comandos (mover, olhar, pular, atirar) de um **controlador**:
  humano (toque, teclado, controle), bot e, no futuro, jogador remoto
- A simulação do personagem não lê mais o teclado nem o toque diretamente
- Pronto quando: tudo funciona como hoje, os 15 testes passam e um bot de teste anda sozinho

### 2. Arma: revólver: [x] feito
- Modelo em primeira pessoa (Low Poly Wild West Guns), tiro por raio (hitscan), munição, recarga
- Mira assistida para toque, coice e balanço por código, clarão, faíscas e sons
- Acertos decididos por um **juiz da partida** (no futuro, esse juiz vira o servidor)
- Pronto quando: atirar funciona no toque, no mouse e no controle, com testes

### 3. Vida, morte e respawn: [x] feito
- Vida, dano, morte e respawn rápido em pontos espalhados, com proteção curta ao nascer
- Indicador de dano e de onde veio o tiro
- Pronto quando: morrer e voltar é rápido e justo

### 4. Partida: todos contra todos: [x] feito
- Placar de abates, cronômetro de 5 minutos, vencedor, tela de resultado, jogar de novo
- Nomes dos jogadores e lista de abates ("A derrubou B")
- Pronto quando: uma partida completa funciona do início ao fim

### 5. Bots: [x] feito (pegar itens fica para a tarefa 8, quando existirem itens)
- Personagem Quaternius + animações da Universal Animation Library
- IA: andar pela arena (navmesh), achar alvos, atirar com erro conforme a dificuldade, pegar itens
- Dificuldades: fácil, médio, difícil
- Pronto quando: você contra 3 bots é divertido, e os bots não travam nem atravessam paredes

### 6. Arena v1 (arte): [x] feito (Sky Plaza; lightmap: ver tarefa 11)
- 3 ilhas ligadas: cidade (Downtown City MegaKit) sobre rochas e vegetação (Stylized Nature MegaKit)
- Layout pensado para combate: coberturas, linhas de visão, pontos de respawn e de itens
- Paleta Nephelia (dourado, creme, azul-céu), colisões, iluminação com LightmapGI, texturas reduzidas
- Pronto quando: a arena fica bonita, os bots navegam nela e o FPS se mantém no iPhone

### 6b. Arena v2: cidade de verdade: [x] feito
- Pedido do usuário (2026-09-22): em vez de ilhas com jardim, quarteirões de cidade flutuantes
- `tools/city_kit.gd` monta prédios com as peças modulares do Downtown City MegaKit (tijolo,
  vitrine, pedra clara; telhado mansarda ou cornija) e junta cada prédio numa malha só com LOD
- Praça central com prédios nos 4 cantos (cruz de ruas), quarteirão residencial a oeste e
  comercial a leste; postes de ferro, balaústres e as "estações" dos trilhos
- Pronto quando: a arena parece uma cidade do começo do século XX e os testes passam

### 7. Trilhos aéreos: [x] feito
- Engatar e desengatar (botão contextual), velocidade, pular do trilho, atirar pendurado
- Bots também usam os trilhos
- Pronto quando: os trilhos viram parte da estratégia da partida
- Feito: 2 trilhos (norte e sul) do jardim ao pátio passando sobre a praça; botão HOOK (tecla E,
  controle Y) aparece perto de um trilho; pendurado dá para acelerar/frear, pular, soltar e atirar;
  no fim o personagem cai freado dentro da ilha. Corpo na pose de pendurado (mão esquerda no
  trilho, pernas no ar). Bots pegam o trilho quando o destino é longe e só soltam onde o pouso é
  chão ligado ao destino. Pendente: testar no iPhone se o HOOK é fácil de alcançar.

### 8. Poderes e itens
- 1 ou 2 poderes com barra de energia (ex.: descarga elétrica, empurrão)
- Itens na arena: vida, munição, energia, armas extras (rifle, espingarda)
- Pronto quando: pegar itens e usar poderes muda o rumo da partida
- Parte 1 (itens): [x] feito. Frascos de vida (+50) que somem ao serem pegos e voltam em 20 s;
  o juiz decide quem pega; aviso no HUD; bots machucados vão buscar o frasco mais perto
- Parte 2 (poderes): REMOVIDA a pedido do usuário (2026-09-22). Estava feita (energia, Faísca e
  Rajada, com testes) e saiu do projeto; está no histórico do Git se um dia voltar
- Parte 3 (armas extras): rifle e espingarda como itens, com munição limitada

### 9. HUD e menus
- Arte dos controles de toque (Kenney Mobile Controls) e mira (Crosshair Pack)
- HUD: vida, munição, energia, placar, lista de abates
- Menu inicial (Jogar contra bots, escolha de dificuldade) e pausa com opções (sensibilidade,
  tamanho dos botões, volume)
- Pronto quando: tudo é legível e alcançável com os dedões num iPhone

### 10. Áudio
- Tiros, passos, impactos, trilhos, poderes, vento, interface e música (se aprovada)
- Trocar o tiro provisório (`assets/audio/sfx/nephelia/revolver_shot_placeholder.wav`, sintetizado)
  por um som de verdade (ex.: Sonniss GDC, depois de aprovado o download)

### 11. Desempenho e ajuste no iPhone
- 6 personagens em tela a 60 FPS estáveis; ajustar sombras, LOD, texturas
- 4 a 6 personagens com 16,5 mil triângulos e árvore de animação cada: medir no iPhone
- LightmapGI da Sky Plaza: o cálculo só roda pelo botão "Bake Lightmaps" no editor (o usuário
  clica, ou o Claude orienta); hoje a arena usa sol dinâmico com sombras
- Pré-aquecer shaders dos efeitos (rastro, faíscas, clarão) ao carregar a arena: o primeiro tiro
  hoje compila shaders e dá um engasgo
- Ajustar sensibilidade e tamanho dos botões com toques reais

### 12. Fechamento do marco 1
- Jogar muitas partidas, corrigir bugs, tag `v0.1` no Git

---

## Marco 2: multiplayer na mesma Wi-Fi
- [ ] Rede com a API de multiplayer do Godot (ENet): um aparelho hospeda e é o servidor
- [ ] Lobby: achar partidas na rede local, entrar, escolher nome
- [ ] Sincronizar jogadores, tiros (o servidor valida os acertos), itens e placar
- [ ] Previsão do próprio movimento e suavização dos outros jogadores (sem "teleportes")
- [ ] Bots completam as vagas vazias
- [ ] Testes com Mac + iPhone e lag simulado
- Pronto quando: 2 ou mais aparelhos jogam juntos sem travadas perceptíveis

## Marco 3: online
- [ ] Servidor dedicado (Godot sem tela) e onde hospedar: VPS ou serviço (Edgegap, W4 Cloud,
      Nakama). Decidir custo antes.
- [ ] Busca de partida (matchmaking) com bots completando vagas; região Brasil primeiro
- [ ] Identidade do jogador (anônimo, Game Center ou Google Play Games) e nomes
- [ ] Proteção básica contra trapaça (servidor decide tiros e movimento)
- [ ] Reconexão, medição de ping
- Pronto quando: dá para jogar com gente de outra cidade

## Marco 4: publicação
- [ ] Nome definitivo (checar marca no INPI e nas lojas), ícone, tela de abertura
- [ ] Modelo de negócio (pago, gratuito com cosméticos, etc.)
- [ ] TestFlight (iOS) com testadores
- [ ] Android: JDK/SDK, exportar, teste interno no Google Play (US$ 25)
- [ ] PC/Steam: modo de controle para PC (desligar emulação de toque, telas de toque e Steam Deck),
      Steamworks (GodotSteam), taxa Steam Direct (US$ 100)
- [ ] Política de privacidade (obrigatória com online), classificação etária, páginas das lojas

---

## Decisões pendentes (do usuário)
- Baixar também: Sonniss GDC 2026 (7,5 GB), músicas do Kevin MacLeod (CC-BY), fontes
  Limelight e Josefin Sans
- Nome definitivo do jogo
- Modelo de negócio
- Hospedagem do servidor online (Marco 3)
- Roupa dos personagens: o pacote grátis de personagens base da Quaternius vem só de roupa de
  baixo (hoje os bots são "manequins" coloridos). Opções: baixar outro pacote grátis com roupa
  (ex.: Quaternius Ultimate Modular Men/Women, CC0) ou encomendar roupas de época
