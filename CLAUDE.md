# Nephelia

Arena de tiro em primeira pessoa, frenética, para celular: partidas rápidas de todos contra
todos (4 a 6 jogadores) em ilhas flutuantes ligadas por trilhos aéreos, com poderes. O visual
é uma cidade flutuante do começo do século XX, inspirada em BioShock Infinite.
Ordem dos modos: **bots → multiplayer na mesma Wi-Fi → online** (bots completam vagas).
Por isso o código deve ficar pronto para rede desde já: personagens recebem comandos de
controladores (humano/bot/remoto) e um "juiz da partida" decide acertos (futuro servidor).
Desenvolvedor solo, iniciante em Godot. O Claude escreve a maior parte do código e das cenas
ao longo de várias sessões; o usuário testa e dá feedback.

## Como trabalhar
- Pedido do usuário (2026-09-22): rodar tudo **em primeiro plano, uma tarefa por vez**. Nada de
  workflows, agentes ou comandos em segundo plano em paralelo; terminar uma tarefa antes de começar outra.
- Pedido do usuário (2026-09-22): ao terminar uma tarefa do `PLANO.md` (testes passando + commit),
  **seguir direto para a próxima**, sem esperar o usuário digitar "continuar". Parar só quando
  precisar de decisão do usuário ou de algo que só ele pode fazer (comprar, criar conta, testar no
  celular, aprovar download).
- Commits direto na `main` estão autorizados (um commit por tarefa concluída).

## Idioma
- Conversar com o usuário em português do Brasil.
- Código, arquivos, nós, variáveis e ações do Input Map em inglês.

## Tecnologia
- Godot 4.7.2 (versão padrão, sem .NET), GDScript com tipagem estática.
- Física: Jolt Physics.
- Renderizador: **Mobile**.
- Plataformas: Android e iOS primeiro; Steam (PC / Steam Deck) depois.

## Regras do projeto
- Todo comando do jogador passa pelo Input Map (`move_forward`, `fire`, `jump`...), nunca
  por teclas fixas, para funcionar com toque, teclado/mouse e controle.
- Orientação paisagem. No Mac, testar com "Emulate Touch From Mouse".
- Desempenho mobile: visual low-poly estilizado, iluminação com LightmapGI, poucas luzes dinâmicas.
- Nada de nomes, personagens, arte ou música de BioShock. O mundo é 100% original.

## Assets
- Decisão (2026-09-22, revisada): usar **somente assets gratuitos**. Preferir CC0; CC-BY só com
  crédito em `CREDITS.md` e nos créditos do jogo. Nunca usar licenças NC, ND ou "uso pessoal".
- Família visual escolhida: **Quaternius MegaKits** (cidade, natureza, personagens e animações do
  mesmo autor, CC0) + Kenney (UI, partículas, sons, CC0). Downloads brutos ficam FORA do projeto
  (`~/Downloads/nephelia_assets/`); só os modelos usados entram em `res://assets/`.
- Baixar qualquer arquivo exige aprovação do usuário no chat (nome, fonte, tamanho).
- Registrar todo asset de terceiros em `CREDITS.md` (nome, autor, loja, licença, link).
- Manter um único estilo visual (não misturar packs de estilos diferentes).
- Assets gerados por IA precisam ser declarados no formulário da Steam.

## Notas técnicas
- Godot está em `~/Downloads/Godot.app` (binário: `Godot.app/Contents/MacOS/Godot`); CLI útil para
  testes headless: `--headless --path . --import` e `-s <script>`.
- Input Map: a ação `fire` aceita só o mouse real (`device` 32 = `InputEvent.DEVICE_ID_MOUSE`). Cliques
  simulados a partir do toque usam `device` -1 e não podem atirar. Se alguém editar `fire` no editor e
  deixar "Todos os dispositivos", todo toque na tela do celular vai atirar.
- `input_devices/pointing/emulate_touch_from_mouse=true` é só para testar no Mac; desligar (ou usar
  override por feature) antes de exportar para PC/Steam.
- Não editar `project.godot` com o editor aberto: o Godot pode sobrescrever. Mudanças de configuração
  via script headless com `ProjectSettings.save()`.
- Estrutura dos personagens: `characters/character.gd` (Character: corpo, movimento, pulo)
  obedece a um `CharacterCommand` (mover, yaw/pitch ABSOLUTOS, pular, atirar) vindo do
  `CharacterController` filho: `player/human_controller.gd` (toque/teclado/controle) ou
  `bots/bot_controller.gd`. Nada no Character lê Input. O HumanController chama
  `apply_look()` na hora (câmera responsiva) e o comando repete o mesmo ângulo.
  `player.tscn` e `bots/bot.tscn` herdam `characters/character.tscn`. Grupos: "characters", "bots".
- Tiro: `weapons/weapon.gd` (Weapon: munição, ritmo, recarga; nó filho do Character) pede ao
  `match/match_referee.gd` (MatchReferee, "juiz", grupo `match_referee`, futuro servidor) que
  resolve o raio, a mira assistida (cone de 8° e até 1 m de desvio, só toque/controle) e a
  imprecisão, e chama `Character.receive_hit()`. Visual separado: `weapons/shot_effects.gd`
  (rastro, faíscas, sons de todos os tiros) e `weapons/view_model.gd` (arma em 1ª pessoa, só do
  jogador local). HUD mínimo em `ui/hud/`.
- Vida/morte: só o MatchReferee muda vida (`apply_damage`), mata (`kill`, também por queda abaixo de
  `fall_limit_y`) e faz renascer (`respawn_now`, após `respawn_delay` = 3 s) no ponto do grupo
  `spawn_points` mais longe dos inimigos vivos, com proteção de 2 s (acaba se atirar). O Character
  só guarda o estado (`health`, `is_alive`, `is_spawn_protected`) e emite `died`/`respawned`.
  Morto: corpo some e a colisão é desligada (`set_deferred`). HUD mostra vida, borda vermelha,
  direção do dano e tela de eliminado; a câmera do humano "cai" ao morrer.
- Partida: `match/deathmatch.gd` (Deathmatch, grupo `game_mode`) escuta `character_died` do juiz,
  conta abates/mortes (queda = morte sem ponto), cronômetro de 5 min e limite de 15 abates; ao acabar
  pausa a árvore (`get_tree().paused`) e emite `match_finished`; `restart()` zera e faz todos
  renascerem. UI local: `ui/match_hud/` (roda pausado) e `ui/match_result/` (PLAY AGAIN, roda pausado).
  O jogador local aparece como "You" no placar e na lista de abates.
- Itens: `items/pickup.gd` (Pickup, grupo `pickups`): área que gira no ar, some quando alguém pega
  e volta depois de `respawn_time`. Quem decide é o MatchReferee (`try_pickup`), como nos tiros.
  Aparência montada em código (`items/pickup_visuals.gd`: frasco de tônico + brilho no chão).
  Os itens da arena saem do `tools/build_skyplaza.gd`; o HUD avisa o que o jogador pegou.
- Bots: `bots/bot_controller.gd` (estados ROAM/CHASE/ATTACK; percepção 10x/s com linha de visão;
  mira com erro que "passeia"; tempo de reação; anda de lado conferindo a navmesh para não cair;
  vira para quem atirou). Dificuldades em `bots/difficulty_{easy,medium,hard}.tres`. `passive`
  = só passeia. Todos usam o mesmo CharacterCommand que o humano (sem trapaça).
- Navegação: `levels/test_level_navmesh.tres` é pré-calculada com `tools/bake_navmesh.gd` (rodar
  de novo ao mudar o cenário). Geometria navegável = grupo `navigation_geometry`. Altura de célula
  10 cm e degrau máx. 20 cm (o personagem só sobe RAMPA, nunca degrau; a escada tem rampa invisível);
  `levels/arena_navigation.gd` ajusta o mapa para a mesma altura de célula.
- Modelo dos personagens: `characters/character_model.tscn` (Quaternius Superhero_Male + revólver na
  mão direita) com árvore de animação montada em código: pernas por velocidade, tronco em pose de
  mira (filtrado a partir de `spine_01`), tiro/levar tiro por cima, transição vida/morte. Animações
  extraídas do UAL para `assets/animations/quaternius_ual/character_animations.res` com
  `tools/extract_bot_animations.gd`. O modelo olha para +Z: dentro do Character ele é girado 180°.
  AnimationNodeTransition começa SEM estado: sempre pedir "alive" ao montar.
- Arena Sky Plaza (`levels/skyplaza/`): três quarteirões de cidade flutuantes (começo do séc. XX),
  gerados por `tools/build_skyplaza.gd` (mapa em código) em `skyplaza_geometry.tscn` (tudo com
  colisão; grupo `navigation_geometry`), `skyplaza_decor.tscn` (só visual), `skyplaza_rails.tscn` e
  `meshes/*.res` (prédios juntados). `skyplaza.tscn` junta sistemas, personagens e 8 pontos de
  nascimento. Mapa: praça central 44 x 44 m com prédios nos 4 cantos formando uma cruz (praça no
  meio + 4 braços; leste/oeste levam às pontes, norte/sul terminam em balaústre onde os trilhos
  passam por cima = "estações"); quarteirão oeste residencial (casas, rua, parque) e leste
  comercial (lojas, largo). Norte = -Z, leste = +X. Ao mudar o mapa: rodar o build e depois
  `tools/bake_navmesh.gd -- <cena> <navmesh.tres>`. Colisões são formas simples (caixa/cilindro/
  convexa), não a malha, e a navmesh lê as colisões (`geometry_parsed_geometry_type = 1`). Nada
  pode ter degrau: os pisos são planos 1 cm acima da plataforma, sem colisão (por isso não se usa
  calçada com meio-fio), e as pontes têm patamares planos na altura de cada quarteirão.
- Nuvens: o `build_skyplaza.gd` gera `skyplaza_clouds.tscn` (aglomerados de esferas achatadas
  numa malha só, sem sombra e sem colisão) por baixo e em volta dos quarteirões: a cidade flutua
  sobre um mar de nuvens e dá para cair atravessando. O "chão" do céu é claro (acima das nuvens),
  senão a base das plataformas fica preta.
- Prédios: `tools/city_kit.gd` (CityKit, só ferramenta) monta fachadas com as peças modulares do
  Downtown City MegaKit (parede de 2 m x 3 m de altura, face de fora para +Z) e junta cada prédio
  numa malha só, com uma superfície por material e LOD automático. Estilos: "brick" (casa de
  tijolo), "shop" (vitrine de ferro) e "civic" (pedra clara); telhado "mansard" (ardósia com
  lucarnas) ou "flat" (cornija). Os lados que não dão para a área de jogo usam peças simples
  (janela cara = até 1100 triângulos). Materiais compartilhados em `assets/materials/city/*.tres`,
  com cor de vértice desligada (senão as peças sem cor ficam pretas), vidro opaco escuro (o
  "interior falso" do pacote é só um plano branco) e sem as faces internas.
- Trilhos aéreos: `rails/skyline_rail.gd` (SkylineRail, um Path3D; grupo `skyline_rails`; tubo CSG e
  postes montados ao carregar). Os da Sky Plaza saem do `tools/build_skyplaza.gd` em
  `skyplaza_rails.tscn`; as pontas ficam ~7 m para dentro da borda das ilhas. O Character engata
  (`find_hookable_rail` no cone do controlador: humano 30°, bot 360°; alcance 10 m a partir do olho),
  é puxado até ficar `RAIL_HANG` = 2 m abaixo do trilho (`is_rail_pulling`) e desliza; comando
  `use_rail` (tecla E / controle Y / botão HOOK, que só aparece com trilho ao alcance). Depois de soltar,
  usar `is_grounded()` (o `is_on_floor()` fica velho por um quadro). Pose de pendurado:
  `characters/rail_grip_modifier.gd` (SkeletonModifier3D que ergue o braço esquerdo) + pernas na
  animação "Jump" (também usada ao pular/cair). Bots: pegam o trilho se o destino está a mais de
  22 m; não se guiam no ar; só soltam se o pouso previsto (com a freada no ar) é navmesh ligada ao
  destino (topo de muro tem navmesh "ilhada"); ao pousar pedem caminho novo.
- Peças usadas: `assets/models/city/downtown/` (84 peças modulares) e
  `assets/models/nature/stylized/` (texturas limitadas a 1024 px no .import). Os prédios prontos do
  pacote (18 a 45 mil triângulos) ficaram de fora por desempenho: a arena usa fachadas montadas.
  Arena inteira hoje: ~286 mil triângulos e 267 superfícies com 4 personagens (medir no iPhone).
- Exportação (preset iOS, `exclude_filter`): `tests/*`, `tools/*`,
  `assets/animations/quaternius_ual/*.glb` (7,6 MB, só serve para extrair animações) e
  `assets/models/weapons/lowpoly_wild_west/*` (FBX de origem; o jogo usa a malha assada). As peças
  soltas da cidade continuam entrando: alguns objetos (guarda-corpo, jardineira, balizador) são
  instâncias delas; os prédios usam as malhas juntadas de `levels/skyplaza/meshes/`.
- Revólver: o FBX do pacote traz a malha 100 vezes menor, com o tamanho numa escala no nó (3 mm de
  malha com escala 100). Isso confunde o LOD automático e **a arma some no iPhone**. Por isso
  `tools/bake_revolver.gd` assa `assets/models/weapons/colt_revolver.res` no tamanho certo, com
  materiais simples, e as cenas usam essa malha. Vale a regra geral: modelo que depende de escala
  grande no nó deve ser assado antes de entrar no jogo.
- Braços em 1ª pessoa: `weapons/hands_view_model.tscn` + `weapons/view_model.gd`. É o mesmo corpo
  e as mesmas animações de pistola do personagem (parado, tiro, recarga, com a velocidade ajustada
  ao ritmo da arma), com a cabeça e as pernas encolhidas pelo `characters/hidden_bones_modifier.gd`
  (o efeito de um SkeletonModifier3D é temporário: não dá para conferir lendo a pose depois).
  O nó fica dentro da câmera, com o modelo 12 cm abaixo dela (osso da cabeça ≈ altura do olho).
  Cada superfície ganha um material novo e simples: o do personagem usa textura ORM, que deixaria
  a pele com brilho de plástico, e os FBX do Wild West Guns têm cores de vértice azuladas. Sempre
  com `use_z_clip_scale` (não atravessa paredes) e `disable_receive_shadows` (senão pega a sombra
  do próprio corpo e fica azul). Coice, balanço ao andar e clarão são por cima, em código.
- Capturas de tela para conferir visual: usar `--write-movie <pasta>/f.png --fixed-fps 60` com um
  script `-s`; `get_viewport().get_texture().get_image()` devolve o quadro ANTERIOR.
- Testes: `Godot --headless --path . -s res://tests/<suíte>.gd` para `test_controls`, `test_bots`,
  `test_arena` e `test_items` (saída 0 = tudo passou). Rodar as quatro depois de qualquer mudança. Ao criar presets de exportação, excluir `tests/*`.
  No headless a janela é 64x64 (viewport 1152x1152): eventos simulados precisam ser convertidos com
  `root.get_final_transform()` (o teste já faz isso). Corpo com `process_mode` desligado sai da
  física (`disable_mode = REMOVE`): nos testes, usar `DISABLE_MODE_KEEP_ACTIVE` para o tiro acertar.
- Godot 4.7 tem classes nativas `VirtualJoystick` e `Logger`: não usar esses nomes em `class_name`.
  Usamos nosso `TouchJoystick` (não o nativo) porque o `TouchControls` distribui os dedos
  centralmente (joystick flutuante na esquerda, olhar no resto da tela, botões).
- `TouchControls.is_touch_mode()` = `DisplayServer.is_touchscreen_available()`. Em modo toque o mouse
  não é capturado e cliques de mouse são removidos de `fire` em tempo de execução. Pendente para a
  Steam: PCs com tela de toque e Steam Deck também entram em modo toque; criar opção de modo de controle.

## Estrutura de pastas (por funcionalidade, cena + script juntos)
```
res://
  characters/  player/  bots/  weapons/  powers/  levels/  ui/  autoload/  tests/
  assets/   # arquivos de terceiros: models/, textures/, audio/, fonts/
```

## Roadmap
O plano completo, com tarefas e critérios de pronto, está em `PLANO.md`. Seguir a ordem de lá,
uma tarefa por vez, e marcar `[x]` ao concluir.

## Estado atual
Atualizar esta seção ao fim de cada sessão.
- 2026-09-22 (fim da sessão 1):
  - Feito: personagem com controladores (humano e bot de teste), controles de toque, fase de
    teste greybox com 1 bot, 18 testes passando. Jogo testado e rodando no iPhone 15 do usuário.
  - Preset de exportação iOS: Team ID 9337P26ZJ6, bundle com.alexandrejunior.nephelia.
    Falta colocar o filtro `tests/*`.
  - Git: commits na `main`. Push pendente: falta criar o repositório privado `nephelia` na conta
    ItsJuniorDias (remoto SSH `origin` já configurado; `gh` não está instalado).
  - Assets: 12 pacotes gratuitos baixados (506 MB) em `~/Downloads/nephelia_assets/` (kenney/,
    quaternius/, weapons/), registrados em `CREDITS.md`, ainda não importados no projeto.
    Downtown City e Nature têm pasta glTF; a Animation Library tem `Unreal-Godot` (.glb);
    as armas são só FBX. Pendentes (aprovar antes de baixar): Sonniss GDC 2026 (7,5 GB),
    músicas do Kevin MacLeod (CC-BY), fontes Limelight e Josefin Sans.
  - Tarefa 2 (revólver) feita: 26 testes passando. Som de tiro ainda provisório (sintetizado).
  - Tarefa 3 (vida, morte e respawn) feita: 31 testes passando.
  - Tarefa 4 (partida todos contra todos) feita: 37 testes passando.
  - Tarefa 5 (bots) feita: 37 testes de controles + 8 de bots passando. Arena com 3 bots
    (Hazel, Otis, Mabel) + jogador. Bots usam o corpo base da Quaternius (sem roupa: decisão pendente).
  - Tarefa 6 (arena Sky Plaza) feita: 3 ilhas + 2 pontes, 37 + 8 + 4 testes passando.
  - Tarefa 7 (trilhos aéreos) feita: 37 + 8 + 10 testes passando. A Sky Plaza virou a cena
    principal e o Input Map ganhou `use_rail`, mudados com o editor aberto: reabrir o Godot.
    Texturas usadas em 3D passaram sozinhas para compressão de GPU (ETC2/ASTC) com mipmaps.
  - Arena v2 (cidade) feita: a Sky Plaza virou três quarteirões de cidade com prédios montados
    peça por peça (CityKit), postes, balaústres e trilhos passando por fora dos prédios.
    37 + 8 + 10 testes passando.
  - Tarefa 8, parte 1 (itens) feita: frascos de vida na arena, bots buscam quando estão
    machucados. 37 + 8 + 10 + 5 testes passando.
  - Braços em 1ª pessoa feitos: mãos segurando o revólver, com animação de parado, tiro e
    recarga. 38 + 8 + 10 + 5 testes passando.
  - Próximo: Tarefa 8 parte 2 (poderes; as ações `power_spark` e `power_gust` já estão no Input
    Map) e parte 3 (armas extras).
