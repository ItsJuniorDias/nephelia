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
- Arena Sky Plaza (`levels/skyplaza/`): gerada por `tools/build_skyplaza.gd` (mapa em código) em
  `skyplaza_geometry.tscn` (tudo com colisão; grupo `navigation_geometry`) e `skyplaza_decor.tscn`
  (só visual); `skyplaza.tscn` junta sistemas, personagens e 8 pontos de nascimento. Ao mudar o
  mapa: rodar o build e depois `tools/bake_navmesh.gd -- <cena> <navmesh.tres>`. Colisões são formas
  simples (caixa/cilindro/convexa), não a malha. Nada pode ter degrau: pisos ficam 1 cm acima do
  chão sem colisão; pontes têm patamares planos na altura de cada ilha.
- Peças usadas: `assets/models/city/downtown/` e `assets/models/nature/stylized/` (texturas
  limitadas a 1024 px no .import). Prédio grande (45 mil triângulos) ficou de fora por desempenho.
- Exportação: excluir `tests/*`, `tools/*` e `assets/animations/quaternius_ual/*.glb` (7,6 MB, só
  serve para extrair animações).
- Arma em 1ª pessoa: materiais com `use_z_clip_scale` (não atravessa paredes),
  `disable_receive_shadows` (senão fica na sombra do próprio corpo e fica azul) e sem
  `vertex_color_use_as_albedo` (os FBX do pacote Wild West Guns têm cores de vértice azuladas).
- Capturas de tela para conferir visual: usar `--write-movie <pasta>/f.png --fixed-fps 60` com um
  script `-s`; `get_viewport().get_texture().get_image()` devolve o quadro ANTERIOR.
- Testes: `Godot --headless --path . -s res://tests/<suíte>.gd` para `test_controls`, `test_bots` e
  `test_arena` (saída 0 = tudo passou). Rodar as três depois de qualquer mudança. Ao criar presets de exportação, excluir `tests/*`.
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
    Pendente: tornar a arena a cena principal (com o Godot fechado).
  - Próximo: Tarefa 7 do `PLANO.md` (trilhos aéreos).
