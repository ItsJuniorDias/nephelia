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
- Textos do JOGO (tudo que o jogador vê) só em inglês, sem opção de idioma (pedido do usuário,
  2026-09-23). Os comentários do código continuam em português.

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
- Decisão (2026-09-22, revisada): usar **assets gratuitos**. Preferir CC0; CC-BY só com
  crédito em `CREDITS.md` e nos créditos do jogo. Nunca usar licenças NC, ND ou "uso pessoal".
  Exceção (2026-09-23): o usuário COMPROU o Marble and Gold UI Kit (interface). Asset pago só
  entra quando o próprio usuário compra; conferir a licença (a desse kit não está escrita).
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
- Aparência dos personagens: ficha `characters/character_look.gd` (CharacterLook: corpo homem ou
  mulher, com ou sem roupa (`dressed`), estampa da roupa, cabelo e cor, barba, chapéu e cor; uma por personagem em
  `characters/looks/*.tres`, no campo `look` do Character). `characters/wardrobe.gd` (Wardrobe)
  monta o corpo EM CÓDIGO: a roupa Peasant do Modular Character Outfits (glTF que já traz o
  esqueleto, braços, mãos e pernas; proporção Regular, quase igual à do Superhero), o corpo com a
  cabeça original, o cabelo, a barba (peças `CharacterPart` = malha + Skin por nome de osso, em
  `assets/models/characters/parts/`) e o chapéu (coco, cartola, boina, feitos de formas simples e
  presos ao osso da cabeça). A textura dos pelos é cinza: a cor vem da ficha. A cor do personagem
  (`body_color`) tinge só o tecido (`Wardrobe.is_cloth`). Os braços da 1ª pessoa usam o mesmo
  Wardrobe (manga da roupa do jogador) e mostram SÓ a malha dos braços (`*_Arms`): a câmera fica
  na altura do pescoço, e a gola/pescoço/peito (tecido com os dois lados visíveis) apareciam como
  uma faixa marrom no meio da tela (visto no iPhone). A foto de conferência `1a_pessoa` já
  mostrava isso: conferir SEMPRE as fotos de 1ª pessoa (reta, para cima e para baixo). Os BOTS (pedido do usuário, 2026-09-22) vestem a roupa
  mas mantêm a cabeça de antes das roupas: corpo masculino, careca, sem chapéu, e a cor deles
  tinge a pele também (`tint_skin`). `dressed` falso ainda monta o corpo original inteiro, sem
  roupa (não usado hoje).
- Peças: `tools/bake_characters.gd` prepara o CORPO (`parts/body_male.res`, `body_female.res`): a
  cabeça ORIGINAL do Universal Base Characters, intacta (o usuário reprovou a cabeça recortada com
  pescoço fabricado), e do tronco só a coluna do pescoço e o decote. A malha é cortada com borda
  lisa (vértices novos no meio das arestas). A pele debaixo da roupa passa a dobrar com os pesos da
  roupa (transferência de pesos do ponto dela mais perto) e a pele que escapa do tecido em alguma
  pose das animações (testada em 10 poses, com raios da física do Godot) sai. Tudo no esqueleto da
  roupa. A cabeça fica 8 cm mais baixa que no corpo original (`HEAD_DROP`, pedido do usuário: "uns
  32 px" nas fotos de rosto); cabelo e barba descem junto e o pescoço encolhe. Conferir com `tools/character_sheet.gd` (fotos, closes do pescoço com e sem roupa).
- Fotos de conferência (`tools/character_sheet.gd`, `tools/pose_sheet.gd`): rodar com janela e
  `-- <pasta>`; cada foto espera quadros realmente desenhados (com a janela escondida o macOS para
  de desenhar e as fotos saíam repetidas).
- **Malha skinned criada em código precisa de `skeleton = NodePath("..")`**: o padrão de um
  `MeshInstance3D.new()` é VAZIO. A cabeça, o cabelo e o chapéu (Wardrobe) ficaram assim até
  2026-09-23: presos na pose de descanso, sem seguir animação nenhuma. Parado não aparecia; correndo,
  o corpo balançava e a cabeça ficava no ar (o usuário viu no vídeo do bot). Teste C3 confere.
- Pernas (2026-09-23, Universal Animation Library **Pro**, comprada pelo usuário, CC0): mistura 2D
  (`AnimationNodeBlendSpace2D`, `sync` ligado) com parado no meio, andar para a frente e as 8
  corridas num círculo (`CharacterModel.JOG_DIRECTIONS`; ponto = direção x velocidade, x =
  esquerda, y = frente). O Character passa o ângulo da caminhada em `update_motion`. As corridas
  giram o quadril (28° a 45°) e o inclinam (20° para a frente, 9° para trás de costas):
  `characters/torso_facing_modifier.gd` (TorsoFacingModifier, PRIMEIRO modificador do esqueleto)
  devolve o `spine_01` à pose do quadril PARADO (média da animação "Idle", onde a mira do revólver
  foi calibrada), a cada quadro: o tronco fica firme na mira (uma média que deixasse passar o
  balanço da passada deixou o tronco até 42° fora). Desligado na morte. Teste C4 (8 direções).
  O pacote Pro fica FORA do projeto (`~/Downloads/nephelia_assets/quaternius/`): o
  `tools/extract_bot_animations.gd` lê o glTF cru de lá (nomes com "_Loop") e só as corridas novas
  entram na biblioteca; o que as duas versões têm é idêntico (conferido osso a osso). O Pro também
  traz mortes, reações a tiro, esquiva, virada de 90°, comemoração etc. (120 animações), ainda não
  usadas.
- Vídeo de conferência: `tools/motion_video.gd` grava um bot andando em todas as direções
  (`--write-movie`, ver o cabeçalho). Para mostrar ao usuário, juntar os quadros num .mp4 com o
  ffmpeg (Homebrew, `/opt/homebrew/bin/ffmpeg`; o usuário instalou em 2026-09-23).
- Modelo dos personagens: `characters/character_model.tscn` (corpo montado pelo Wardrobe + arma na
  mão direita) com árvore de animação montada em código: pernas por direção e velocidade, tronco em pose de
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
- Gramado do parque (oeste): textura pintada à mão (Stylized Grass & Dirt, JulioVII, **CC-BY**:
  crédito no jogo) + tufos de capim e flores do Nature Kit espalhados pelo `build_skyplaza.gd`
  (`LAWN_PLANTS`) em nós `levels/lawn_plants.gd` (LawnPlants: MultiMesh montado AO ABRIR a partir de
  `transforms`; gerado sem janela o Godot não guarda os dados de um MultiMesh e as plantas iam para
  a origem). Somem a 40 m, sem sombra nem colisão. `tools/texture_audit.gd` lista o que está sem
  textura na arena (nuvens, vidro, globos, frascos e armas são lisos de propósito).
- Rodar o `build_skyplaza.gd` renumera os `unique_id` de TODAS as cenas: aplicar só as mudanças
  reais em cima das cenas antigas (ou aceitar o diff grande conscientemente).
- Céu da tarde à noite: `levels/sky/sky_cycle.gd` (SkyCycle, criado pelo ArenaSetup) segue o
  relógio da partida (começo = tarde dourada, 30% = pôr do sol, 44% = crepúsculo, 60%+ = noite;
  "Play Again" volta à tarde) por quadros-chave (`KEYS`) e aplica no céu próprio
  (`levels/sky/sky_cycle.gdshader`: degradê, clarão do pôr do sol, sol, estrelas que piscam,
  nebulosa com veios, lua; estrelas e nebulosa GIRAM em volta de um polo inclinado e a poeira muda de
  forma com o TIME), na luz (o mesmo DirectionalLight vira o luar azulado; nunca abaixo de 9°), no
  ambiente (cor, não o céu), na névoa e no bloom (só à noite). Os postes (grupo `lamp_globes`)
  acendem: globo brilhando + OmniLight sem sombra que some longe da câmera (celular). As nuvens
  (grupo `drifting_clouds`, o nó Clouds da arena) giram devagar em volta do centro, o dia todo.
  Reflexo do céu de 32 px, atualizado aos poucos. `forced_progress` força um momento (fotos em
  `tools/sky_sheet.gd`; testes V5 e V6). **A luz muda durante a partida: LightmapGI (Tarefa 11) não
  pode assar a luz do sol** (no máximo luz indireta fraca, ou nada).
- Nuvens: o `build_skyplaza.gd` gera `skyplaza_clouds.tscn` (aglomerados de esferas achatadas
  numa malha só, sem sombra e sem colisão) por baixo e em volta dos quarteirões: a cidade flutua
  sobre um mar de nuvens e dá para cair atravessando. O "chão" do céu é claro (acima das nuvens),
  senão a base das plataformas fica preta.
- Prédios: `tools/city_kit.gd` (CityKit, só ferramenta) monta fachadas com as peças modulares do
  Downtown City MegaKit [Source] (comprado pelo usuário em 2026-09-24, CC0; peças de 2 ou 4 m de
  largura, 3 ou 4 m de altura, face de fora para +Z; quantos módulos a peça ocupa sai da largura
  dela) e junta cada prédio numa malha só, com uma superfície por material e LOD automático.
  Estilos (`STYLES`, cada um com altura de andar, peças do térreo/andares/topo, porta, cantos,
  cornija e faixa): "brick", "brick_bay" (janelas salientes), "shop", "civic", "bank" (mármore,
  andares de 4 m), "hotel" (tijolo branco com janelas salientes) e "tenement" (tijolo gasto);
  telhado "mansard" ou "flat". Enfeites por prédio: `band` (faixa de 1 m em cima do térreo, onde vão
  os letreiros), `awnings` (toldos), `signs` (letreiros e placas de pendurar, com `scale`) e
  `fire_escape`. Letreiros com telefone moderno (Kowalski's Deli, May's Salon) ficam de fora.
  Nada sai das faces norte/sul de fora dos prédios da praça (os trilhos passam perto).
- Materiais da cidade (2026-09-24): o `tools/city_import_script.gd` (script de importação de todas
  as peças de `assets/models/city/downtown/`) troca os materiais do glTF pelos do projeto em
  `assets/materials/city/`: o shader do pacote (`M_BaseMaterial.gdshader`: desgaste nas quinas pelo
  2º UV, sujeira pela cor do vértice; o z do relevo é CALCULADO, porque a compressão de celular só
  guarda x e y e as paredes ficavam granuladas) e a sala atrás da janela
  (`fake_interior.gdshader`, nosso, baseado no do pacote: sorteio por JANELA na cor do vértice, que
  o CityKit grava por pedaço solto da superfície; `night` faz as salas acesas brilharem em luz
  quente, e o SkyCycle muda junto com os postes; sem transparência). O CityKit mantém cor de vértice
  e 2º UV e tira o vidro das peças que têm sala. Texturas em `assets/materials/city/textures/`
  (1024 px, VRAM). Tijolo gasto clareado (`color_tint`) para combinar com a luz quente.
  Conferir com `tools/city_sheet.gd` (fotos de pontos fixos, tarde e noite) e
  `tools/city_flythrough.gd` (sobrevoo em vídeo).
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
- Peças usadas: `assets/models/city/downtown/` (141 peças da versão Source) e
  `assets/models/nature/stylized/` (texturas limitadas a 1024 px no .import). Os prédios prontos do
  pacote (18 a 45 mil triângulos) só aparecem no HORIZONTE: 7 ilhas flutuantes sem colisão nem
  sombra (`skyplaza_skyline.tscn`, `SKYLINE` no build), com `lod_bias` baixo. Portais de pedra
  (Prop_EntranceArch, escala 1,6, vão de 2,85 m) nas pontas das pontes, com colisão só nas colunas.
  Triângulos por quadro (medidos no Mac, com sombras, sem personagens): 440 a 690 mil (antes 330 a
  520 mil); chamadas de desenho quase iguais (146 a 335). Medir no iPhone (Tarefa 11).
  Com roupa cada personagem tem ~21 a 24 mil triângulos e 10 a 13 superfícies (antes 14 mil e 3).
- Exportação (preset iOS, `exclude_filter`): `tests/*`, `tools/*`,
  `assets/animations/quaternius_ual/*.glb` (7,6 MB, só serve para extrair animações),
  `assets/models/weapons/lowpoly_wild_west/*` (FBX de origem; o jogo usa a malha assada) e os
  glTF/bin de `quaternius_hair/` (só servem para assar as peças). Os glTF de `quaternius_ubc/`
  ENTRAM (o corpo sem roupa, `dressed` falso, usa). As peças
  soltas da cidade continuam entrando: alguns objetos (guarda-corpo, jardineira, balizador) são
  instâncias delas; os prédios usam as malhas juntadas de `levels/skyplaza/meshes/`.
- Armas (malhas): os FBX do pacote trazem a malha 100 vezes menor, com o tamanho numa escala no nó
  (3 mm de malha com escala 100). `tools/bake_weapons.gd` assa revólver, repetidora e espingarda em
  `assets/models/weapons/*.res` no tamanho certo, com materiais simples, e imprime a ponta do cano.
  Regra geral: modelo que depende de escala grande no nó deve ser assado antes de entrar no jogo.
- Armas (fichas): `weapons/weapon_data.gd` (WeaponData: dano, ritmo, tambor, reserva, chumbos,
  coice, som, pegadas) e `weapons/weapon_catalog.gd` (WeaponCatalog, as três fichas em código). O
  nó `Weapon` é sempre o mesmo: pegar arma troca a ficha (`equip`); a reserva acaba e ele volta
  sozinho ao revólver (`refill` = revólver cheio, usado no respawn). Itens `Pickup.Kind.RIFLE` e
  `SHOTGUN` (`Pickup.weapon_id_of`) passam pelo juiz (`MatchReferee.give_weapon`); chumbos da
  espingarda = vários raios num `ShotResult` (`pellet_points`).
- **Nó dentro de cena instanciada não sobrevive ao build do iOS**: a arma era um nó guardado dentro
  da cena do modelo glTF (filho do esqueleto). No Mac funcionava; no iPhone o nó simplesmente não
  existia e ninguém aparecia armado (levou uma sessão inteira para achar, com um painel de
  depuração na tela do aparelho). Agora `characters/gun_mount.gd` cria a arma em código, num
  `characters/weapon_mount.gd` (nosso BoneAttachment3D) que segue o osso `hand_r`. Ao pendurar algo
  num modelo importado, montar em código.
- Pegada das armas: as animações são todas de PISTOLA. O revólver fica na mão direita (segue o osso
  `hand_r`) com a pegada CALCULADA pela mão da animação (2026-09-23, aprovada pelo usuário): o cabo
  passa no centro do punho fechado (médio, anelar e mínimo em volta de (-0,034; 0,090) no espaço da
  mão) e a face do gatilho (0; 0,075; 0,033 na arma) fica na ponta do indicador; girada 9,2°
  (`hand_turn`) para o cabo seguir a linha dos nós dos dedos. Antes a arma ficava 3,5 cm fora do
  punho, em cima dos dedos. Conferir com `tools/grip_closeup.gd` (close-ups da mão e do gatilho). Com
  essa pegada a pose de mira aponta o cano 21,4° para cima: `CharacterModel.PISTOL_AIM_*` calibra a
  pose para o cano seguir a mira (medir de novo se a pegada mudar; teste I11). Em 1ª pessoa o
  `ViewModel` usa a correção de mira também no revólver (parada durante a animação do tiro) e sobe os
  braços 10 cm e 4 cm para a esquerda (`pistol_view_offset`), senão o revólver caía para o pé da tela.
  `pistol_shift` (zero hoje) desloca só a arma com as mãos indo junto por IK (`keep_animation_elbow`). Armas longas ficam apoiadas na frente do corpo
  (`WeaponData.chest_mount`, girando com a mira em volta de `WeaponMount.CHEST_PIVOT`) e as DUAS
  mãos vão até elas por `characters/weapon_grip_modifier.gd` (IK de dois ossos nossa; o
  `TwoBoneIK3D` do Godot 4.7 não mexeu neste esqueleto). Pegadas descritas como mão de verdade
  (`WeaponCatalog.hand_pose`: contato, nós dos dedos, polegar); o esqueleto é espelhado no eixo X,
  então a esquerda usa as mesmas direções. A mão esquerda copia os dedos fechados da direita
  (espelhados: quaternion com y e z trocados de sinal). Coice e recarga das armas longas mexem a
  própria arma no `WeaponMount` (as mãos vão junto). O alcance foi medido de -85° a +85° de mira,
  no chão e no ar (a pose de pulo mexe o quadril): `WeaponGripModifier.miss` mostra quanto faltou.
- Armas longas NO OMBRO (2026-09-23, aprovado pelo usuário com fotos antes/depois): a coronha
  (`butt` na ficha) fica em `WeaponCatalog.SHOULDER_POCKET`, bem dentro do ombro direito, 8° para
  dentro. O `WeaponMount` acompanha o peito (`spine_03`, comparado à pose de mira parada
  `CHEST_NEUTRAL`) e gira em volta do ombro só o que falta para a mira; ele se atualiza DENTRO da
  etapa do esqueleto (`characters/weapon_mount_sync.gd`, depois do TorsoFacing e antes das mãos): no
  `_process` lia o peito atrasado e a mão esquerda ficava até 10 cm longe correndo. O braço esquerdo
  trabalha perto do limite: coronha mais para a frente = mão sem alcance (teste I9 varre -85° a +85°,
  no ar e correndo).
- 1ª pessoa das armas longas: posição PRÓPRIA (`WeaponData.view_mount`, `view_at`/`view_aim` na
  ficha): no ombro, visto de trás, a coronha e as mãos tapavam a tela. Baixa e à direita, com as duas
  mãos e a armação à vista; o `ViewModel` gira os braços em volta do olho até o cano cruzar a mira a
  12 m (`get_aim_error_degrees`) e ergue os braços 12° na recarga. O revólver fica sem correção.
- Conferir pose de arma: `tools/pose_sheet.gd` (fotos em 1ª pessoa, de frente, de lado, de costas
  e no meio da recarga; ver o cabeçalho). Rodar com `--always-on-top`: com a janela escondida o
  macOS para de desenhar e todas as fotos saem iguais.
- Atenção: no arquivo `.tscn` a matriz de um `Transform3D` é escrita por LINHAS; no construtor em
  código, por COLUNAS (uma é a transposta da outra).
- Braços em 1ª pessoa: `weapons/hands_view_model.tscn` + `weapons/view_model.gd`. É o mesmo corpo
  e as mesmas animações de pistola do personagem (parado, tiro, recarga, com a velocidade ajustada
  ao ritmo da arma), com a cabeça e as pernas encolhidas pelo `characters/hidden_bones_modifier.gd`
  (o efeito de um SkeletonModifier3D é temporário: não dá para conferir lendo a pose depois).
  O nó fica dentro da câmera, com o modelo 12 cm abaixo dela (osso da cabeça ≈ altura do olho).
  Cada superfície ganha um material novo e simples: o do personagem usa textura ORM, que deixaria
  a pele com brilho de plástico, e os FBX do Wild West Guns têm cores de vértice azuladas. Sempre
  com `use_z_clip_scale` (não atravessa paredes) e `disable_receive_shadows` (senão pega a sombra
  do próprio corpo e fica azul). Coice, balanço ao andar e clarão são por cima, em código.
  A arma no corpo visto de fora não é tingida com a cor do personagem (o aço ficava cor de pele).
- Menus: `ui/main_menu/` (cena principal do jogo), `ui/pause_menu/` (dentro do jogador, com
  `process_mode` sempre, senão os botões não responderiam com o jogo pausado) e `ui/options_menu/`
  (usado pelos dois). As telas são montadas por `tools/make_menus.gd`. Ao montar cena em código,
  marcar o dono só dos nós criados ali: nos filhos de uma cena instanciada, ela é salva duas vezes.
- Opções: `autoload/settings.gd` é uma CLASSE ESTÁTICA (`Settings`), não um autoload: no modo de
  teste (`-s`) o compilador do Godot não reconhece o nome de um autoload, mas reconhece
  `class_name`. Guarda sensibilidade, tamanho dos botões, volume e dificuldade em
  `user://settings.cfg`. Quem precisa reagir a mudanças compara `Settings.version` (sinal estático
  não existe). `levels/arena_setup.gd` aplica a dificuldade aos bots ao abrir a arena (com
  `call_deferred`: os bots ficam prontos depois dele).
- Arte da interface: **Marble and Gold UI Kit** (pago, mármore verde, cobre e ouro), em
  `assets/ui/marble_gold/`. Quase tudo vem do TEMA (`tools/make_theme.gd`, peças em "nove fatias"):
  Button/TitleButton (trapézio de mármore; dourado com foco), "MenuItem" (só texto, barra de cobre
  atrás do selecionado), PanelContainer (janela de mármore), HSlider (trilho, laranja e alça
  quadrada), ProgressBar, CheckBox, OptionButton, VScrollBar, "HudTag" (etiqueta preta inclinada
  atrás dos textos do HUD) e "HudBanner" (faixa de cobre). O menu inicial é o monumento do kit com
  a janela de cobre centrada (`tools/make_menus.gd`, `MONUMENT_SCALE`); o placar final
  (`ui/match_result/`) é uma tabela na janela de "banco de dados" entre colunas de mármore. Anéis
  dos botões de toque e do joystick são do kit; os ícones (mira, pulo, recarga, mão, pausa) e o
  pino do joystick continuam do **Kenney Mobile Controls**, com fundo escuro por baixo. A fonte do
  corpo é a Josefin Sans em peso 600 (`FontVariation`): o padrão da fonte variável é o 100, fino
  demais. Conferir tudo com `tools/ui_sheet.gd` (fotos de todas as telas).
- HUD: `ui/hud/health_bar.gd` (trilho e preenchimento do kit, com o número dentro e um rastro claro do dano) e
  `ui/hud/ammo_pips.gd` (uma bala por tiro do tambor; na recarga elas acendem no ritmo dela).
  O botão de pausa na tela aperta a AÇÃO `pause`, e quem lê isso é o `PauseMenu` no `_process`
  (botão de toque não manda evento de input).
- Interface: o tema `ui/theme/nephelia_theme.tres` (gerado por `tools/make_theme.gd` e aplicado a
  tudo por `gui/theme/custom`) traz as fontes: Josefin Sans na interface e Limelight (Art Déco) nos
  títulos, pela variação de tipo "Title"/"Subtitle"/"TitleButton". Nome de classe do Godot não pode
  virar variação de tipo (ex.: "MenuButton").
- Capturas de tela para conferir visual: usar `--write-movie <pasta>/f.png --fixed-fps 60` com um
  script `-s`; `get_viewport().get_texture().get_image()` devolve o quadro ANTERIOR.
- Áudio: `audio/sounds.gd` (Sounds: todos os sons num lugar, `play_3d`/`play_2d`/`music`/
  `wire_buttons`). Canais em `default_bus_layout.tres` (feito por `tools/make_audio_buses.gd`):
  Master (limitador) → Music, SFX, UI; `Settings.volume` e `Settings.music_volume`. Arquivos
  preparados por `tools/prepare_sounds.py` (Python puro + `afconvert` do macOS: mono 44,1 kHz,
  normaliza, sintetiza o chiado do trilho) a partir de `~/Downloads/nephelia_assets/`.
  `characters/character_audio.gd` (criado em código pelo Character): passos por distância andada,
  com o tipo de chão de `levels/floor_surfaces.gd` (o `build_skyplaza.gd` guarda a lista dos pisos
  como metadado da geometria: os pisos não têm colisão), pulo, aterrissagem, dano, morte, trilho e a
  recarga dos outros. A recarga vem da ficha da arma (`WeaponData.reload_sound`). O TIRO é o
  sintetizado do projeto (`revolver_shot_placeholder.wav`, no `ShotEffects`), num tom por arma
  (`shot_pitch`): o usuário testou tiros gravados de armas reais e não gostou (2026-09-22).
  `levels/arena_ambience.gd` (criado pelo ArenaSetup): vento e música da partida. Música e sons de
  interface tocam com o jogo pausado (`PROCESS_MODE_ALWAYS`). Loops: marcar no `.import`
  (`loop=true` no OGG, `edit/loop_mode=2` no WAV).
- Sons de meme (pedido do usuário, 2026-09-24: "jogo engraçado"): `audio/meme_sounds.gd`
  (MemeSounds, criado pelo ArenaSetup) toca sons por cima da partida a partir dos sinais do juiz,
  da partida e da arma do jogador local (funciona igual no multiplayer): gongo no início, "dun dun
  DUNNN" aos 30 s, boom no tiro na cabeça que elimina, bonk sem matar, buzina a cada série de 3
  abates, arranhão de disco + imagem congelada ("Yep, that's me.") ao morrer depois de uma série,
  marcha fúnebre em 3 mortes seguidas, grilos ao errar um tambor inteiro, ka-ching ao pegar arma,
  bipe de erro, apito de desenho em quem cai da ilha, risada quando um bot cai sozinho, "ba dum
  tss", cano de metal, boing, kazoo (1º) e trombone triste (último); modem ao entrar numa sala do
  Wi-Fi. Só enfeite; opção FUNNY SOUNDS (`Settings.funny_sounds`, ligada de fábrica). NUNCA usar
  sons de meme originais (trechos de filmes/jogos/músicas, vozes de gente real): o usuário aceitou
  fazer a nossa versão. Sons em `assets/audio/sfx/memes/` por `tools/make_meme_sounds.py`
  (sintetizados em Python puro + trechos de 4 gravações CC0 do Freesound baixadas pelo usuário em
  `~/Downloads/nephelia_assets/audio/freesound/`). Vídeo de conferência: `tools/meme_demo.gd`.
  Teste S8 (test_audio) e M3 (opção).
- Efeitos visuais: `vfx/vfx.gd` (Vfx, funções estáticas: fumaça e clarão do cano, faíscas, poeira e
  marca do tiro, nuvem no corpo atingido, poeira da aterrissagem, fumaça do corpo que some, anel de
  quem renasce, faíscas do gancho) com imagens do Kenney Particle Pack em `assets/vfx/kenney/` (256 px,
  com mipmaps). O `ShotEffects` usa por raio (`ShotResult.ray_normals`/`ray_hit_character`; a
  espingarda deixa uma marca por chumbo, até `MAX_MARKS`); `characters/character_effects.gd`
  (CharacterEffects, criado em código pelo Character) cuida do trilho, da queda, da morte e do
  renascimento. **`CPUParticles3D` criado em código nasce com `emitting = true`** e solta tudo ao
  entrar na cena, ainda na origem do mapa (dentro do monumento da praça): criar DESLIGADO, posicionar
  e chamar `restart()`. Por isso as faíscas antigas do tiro nunca apareceram (e usavam uma imagem de
  raio elétrico). Brilho somado (`BLEND_MODE_ADD`) some contra o céu claro: faíscas do trilho usam
  mistura normal. Conferir com `tools/effects_sheet.gd` (fotos; ver o cabeçalho).
- Ícone: `ui/icon/app_icon.png` (1024 x 1024, sem transparência), em `config/icon` e no iOS
  `icons/icon_1024x1024` (os outros tamanhos vazios do preset usam o `config/icon`, o mesmo arquivo). Feito por IA com `tools/make_icon.py` (Python:
  OpenRouter + Nano Banana `google/gemini-2.5-flash-image`; chave em `.env`, fora do Git): `generate`
  cria opções em `~/Downloads/nephelia_assets/icon/candidates/` (com fotos do jogo de
  `tools/icon_reference.gd` como referência de estilo) e `use <imagem>` aplica. Escolhido pelo
  usuário: o emblema (revólveres cruzados, gancho, sol Art Déco, fundo azul-petróleo).
- Testes: `Godot --headless --path . -s res://tests/<suíte>.gd` para `test_controls`, `test_bots`,
  `test_arena`, `test_items`, `test_menus`, `test_audio` e `test_net` (saída 0 = tudo passou). Rodar
  as sete depois de qualquer mudança. Num script de teste (`extends SceneTree`) não existe `get_tree()`: o próprio
  script é a árvore (usar `self.paused`, `root`, `get_nodes_in_group`). Ao criar presets de exportação, excluir `tests/*`.
  No headless a janela é 64x64 (viewport 1152x1152): eventos simulados precisam ser convertidos com
  `root.get_final_transform()` (o teste já faz isso). Corpo com `process_mode` desligado sai da
  física (`disable_mode = REMOVE`): nos testes, usar `DISABLE_MODE_KEEP_ACTIVE` para o tiro acertar.
- **Multiplayer** (`net/`, 2026-09-23): o anfitrião é o servidor. `Net` (classe estática: modo,
  conexão, sala `roster`, `last_error`); `NetTransport` = "estrada" trocável (`EnetTransport` para
  Wi-Fi local e testes no Mac; o Game Center entra no mesmo lugar, via GodotApplePlugins/GKMatch).
  Protocolo PRÓPRIO (`NetMessage`: comandos binários 60/s; `NetSnapshot`: foto do estado 30/s;
  eventos confiáveis em `var_to_bytes` sem objetos), sem RPC do Godot. `NetLobby` = sala sem tela
  (HELLO/ROSTER/START), usada pela tela `ui/lobby/` (montada no `make_menus.gd`) e pelos testes.
  Pedidos do usuário: até 4 PESSOAS por partida (`Net.MAX_PLAYERS`, 2026-09-24) e o anfitrião
  começa pelo botão START quando todo mundo entrou (2026-09-24; de 2026-09-23 até então a sala
  começava sozinha quando alguém entrava: `NetLobby.auto_start_delay`, hoje -1 e só usado nos
  testes); quem chega depois entra no meio, no lugar de um bot. SEM digitar endereço: o anfitrião responde na porta `Net.DISCOVERY_PORT` (`LanBeacon`, ligado por
  `Net.host_lan` e lido por `Net.poll`) e a sala procura com `LanScanner`, que pergunta endereço por
  endereço na rede x.x.x.1-254 (broadcast no iPhone exigiria a permissão de multicast da Apple;
  unicast só precisa da permissão de rede local). A tela mostra "JOIN <NOME>'S GAME (1/4)".
  Na arena o `ArenaSetup` cria `NetHost` ou `NetClient` (`net/net_game.gd` em comum: personagens por
  `net_id`, trilhos e itens por índice, lê pacotes com prioridade -100 e `PROCESS_MODE_ALWAYS`).
  Anfitrião: `RemoteController` (fila de comandos numerados; se o comando atrasa, o personagem
  ESPERA até 200 ms e depois o `NetHost._catch_up` alcança com passos extras: adivinhar ou jogar
  comandos fora dava correções de 0,7 m), compensação do atraso no tiro (`MatchReferee.shot_rewinder`
  volta os alvos para onde o atirador os via, até 300 ms), bots completam até `Net.MIN_CHARACTERS` = 4
  (pedido do usuário: partida frenética; quem entra toma a vaga de um bot, quem sai devolve).
  Cliente: prevê o próprio movimento (`Character.step_movement`; `command_hook` numera e manda) e
  corrige com `Character.reconcile` quando a foto discorda (> 3 cm); os outros são marionetes
  (`PuppetController`, 100 ms no passado, `apply_puppet_state`); eventos do anfitrião são
  repassados pelos MESMOS sinais do juiz/partida (HUD, sons e efeitos não sabem que é rede).
  `MatchReferee.authority`/`Deathmatch.authority` falsos no cliente (não mata, não dá item, não
  acaba a partida); o tiro do cliente é desenhado na hora e o acerto chega depois
  (`Weapon.hit_confirmed`); imprecisão sorteada pelo número do comando (cliente e anfitrião iguais).
  Na rede os personagens NÃO se bloqueiam (collision exceptions): esbarrão em marionete no passado
  virava correção. Pausa não congela a partida em rede; só o anfitrião recomeça ("WAITING FOR
  HOST"). Etiqueta de nome sobre os outros (`characters/name_tag.gd`: gente em dourado, bot em
  cinza com "BOT"; some atrás de parede); placar final marca "(BOT)".
  Armadilhas já pegas: (1) o "acelerador" do ENet joga fora pacotes não confiáveis quando acha
  que a rede congestionou (logo após carregar a arena): sumiam fotos por ~1 s e tiros; está
  desligado em `EnetTransport` (`throttle_configure(..., 0)`) e o SHOT é confiável. (2) O aviso
  CHARACTER_ADDED chega ao próprio cliente antes do WORLD: ele criava uma marionete de si mesmo que
  o empurrava 0,69 m; o cliente ignora esse aviso antes do mundo e nunca cria a própria marionete.
  Testes: `tests/test_net.gd` abre OUTRO processo do Godot como anfitrião (`tests/net_host_runner.gd`,
  relatório em JSON) e joga como cliente. Fotos: `tools/net_sheet.gd` (com janela; abre processos
  ajudantes). No Mac: no editor, Debug > Customize Run Instances = 2 janelas (uma hospeda, a outra
  entra: a sala aparece sozinha). iPhone: o preset iOS tem `NSLocalNetworkUsageDescription`
  (`additional_plist_content`); sem ele o iOS bloqueia a rede local calado (a primeira procura de
  salas pede a permissão ao jogador).
- **Online** (2026-09-24; decisões do usuário: hospedagem no RENDER (ele já paga o Starter de
  US$ 7; não quer Oracle), sem contas por enquanto, jogo cruzado Steam/Mac/iPhone/Android). O Render
  não aceita UDP e não tem região no Brasil (Virginia é a mais perto, ~120-150 ms): a partida online
  vai por WebSocket (`net/websocket_transport.gd`, `wss://<serviço>/play/<partida>`, repassado pelo
  matchmaker para o servidor da partida na mesma máquina; Nagle desligado); o Wi-Fi local continua
  ENet (UDP). O backend também tem o modo `enet` (VPS com UDP), se um dia mudar. Backend em Node.js +
  TypeScript no repositório SEPARADO `~/nephelia-server` (github.com/ItsJuniorDias/nephelia-server;
  matchmaker: `POST /v1/matchmake`, enche a partida mais cheia com vaga, abre e fecha partidas,
  README com o passo a passo da Oracle). A partida online NÃO roda no Node: é o próprio jogo sem tela
  (servidor dedicado), aberto pelo matchmaker com `-- --server --port=N --match-id=X`: o
  `MainMenu._ready` vê `DedicatedServer.requested()` e liga `net/dedicated_server.gd`, que chama
  `Net.host_dedicated` (NetHost com `Net.dedicated`: o personagem da cena sai, bots completam até 4
  com `Net.host_seats()` = 0, vazio fica pausado esperando, recomeça sozinho 12 s depois do fim e
  volta a esperar quando o último sai) e escreve na saída `NEPHELIA {"event":"ready"|"status"|"bye"}`.
  O ArenaSetup não cria céu, som nem sons de meme no servidor. Cliente: botão PLAY ONLINE na tela
  MULTIPLAYER (`net/online_matchmaker.gd`: HTTPRequest ao matchmaker, mensagens de erro por código;
  `OnlineMatchmaker.SERVICE_URL` = https://nephelia-server.onrender.com desde 2026-09-24 (vazio = o
  botão some); `-- --matchmaker=<url>` troca o endereço em teste),
  depois `Net.join_online` + NetLobby (o servidor manda START na hora). Testes N21 (servidor dedicado
  num processo), N22 (ponta a ponta com o Node, ENet), N23 (ponta a ponta por WebSocket, como no
  Render) e N24 (estrada do WebSocket: "para todos" do cliente = anfitrião, por onde vai o LEAVE);
  N22/N23 pulam se o Node ou o `../nephelia-server` faltarem. Testado contra o Render do Mac
  (2026-09-24): partida em 0,4-0,8 s, arena em ~2 s, ida e volta de ~250 ms (Brasil -> Virginia,
  ~15 comandos sem resposta). A plataforma do Render sonda as portas abertas da máquina com pedidos
  HTTP simples, 1 por segundo, e o servidor da partida reclama de cada um ("Not enough response
  headers, got: 3"): é ruído, não jogador; o matchmaker junta linhas repetidas (1 por minuto, com
  `repeated`). Servidor dedicado com
  `--transport=websocket --bind=127.0.0.1`. No Render: `game/nephelia_server.pck` no repositório do
  backend (preset "Linux Server" = servidor dedicado, visuais trocados por marcadores: nenhuma arte
  paga no repositório público) e o Godot oficial Linux baixado no build (`scripts/install_godot.sh`).
  O Godot "editor" oficial rodando um .pck tem a marca "debug" (já solta as linhas na hora).
  Node.js 24 LTS no Mac em `/opt/homebrew/opt/node@24/bin` (keg-only). Preset "Linux Server"
  (`export_filter="customized"`, `res://` = "strip", tests/tools removidos): exportar com o editor
  FECHADO por `Godot --headless --path . --export-pack "Linux Server"
  ../nephelia-server/game/nephelia_server.pck` (8 MB) e fazer commit no backend A CADA mudança de
  rede/partida (o servidor tem que ter o mesmo código dos jogadores). No pacote sem arte os
  materiais, malhas e texturas viram marcadores vazios: constante com tipo exato de visual
  (ex.: `const X: ShaderMaterial = preload(...)`) não compila lá; usar o tipo geral (`Material`).
- Publicação (App Store, decidido 2026-09-23: jogo PAGO, iPhone e iPad, nome Nephelia, versão
  1.0 build 1): créditos no jogo em Opções > CREDITS (`ui/credits/credits_screen.gd`, lista igual ao
  `CREDITS.md` + licenças do Godot via `Engine.get_license_text()`/`get_copyright_info()`; a textura
  CC-BY do JulioVII EXIGE esse crédito). Preset iOS: `short_version` 1.0, `version` 1,
  `ITSAppUsesNonExemptEncryption` falso no `additional_plist_content`. Textos da loja, notas do
  revisor e questionários em `store/app_store_listing.md`; política de privacidade em
  `store/privacy_policy.html` (o usuário publica num link público e troca CONTACT_EMAIL). Prints da
  loja: `tools/store_screenshots.gd` (SubViewport do tamanho exato: 2868 x 1320 iPhone 6,9" e
  2752 x 2064 iPad 13", com o 2D na escala do jogo por `size_2d_override`), saída em
  `~/Downloads/nephelia_assets/app_store/screenshots/`. O formato do iPad (4:3) foi conferido com
  `tools/ui_sheet.gd --resolution 1024x768`: menus e HUD se ajustam. O App Store Connect pediu a
  caixa de iPhone **6,5"** (2778 x 1284, aparelho `iphone65` na ferramenta), não a de 6,9".
  Vídeo de prévia (App Preview): `tools/app_preview.gd` grava 4 cenas de jogo de verdade (tarde,
  trilho no pôr do sol, espingarda, noite) com o jogador pilotado pelos CONTROLES DE TOQUE (joystick
  e botões apertados de verdade, mira suave, caça o bot vivo mais perto), bots fáceis sem trilho,
  vida nunca abaixo de 30 e música muda; quadros de uma SubViewport do tamanho exato (1920 x 886
  iPhone, 1600 x 1200 iPad; o Movie Maker só grava no tamanho da janela do projeto) e som do
  Movie Maker (`game.avi`). `tools/make_app_preview.py` monta o .mp4 com o ffmpeg (Homebrew):
  H.264 High 4.0, 30 fps, ~10 Mbps, AAC 256k, som cortado igual aos trechos e ADIANTADO 2 quadros
  (o `get_image()` devolve o quadro anterior), música contínua por cima. Saída em
  `~/Downloads/nephelia_assets/app_store/preview/`. A Apple só aceita gravação do próprio app na
  prévia (regra 2.3.4): vídeo gerado por IA (ex.: Seedance) só serve para trailer fora da loja.
  Página de suporte: `store/support.html` (o usuário publica suporte e política no Notion).
  Build da loja (2026-09-24, funcionou): o preset iOS exporta SÓ o projeto do Xcode
  (`export_project_only`) para `~/Builds/nephelia_ios/` (FORA do projeto: exportar dentro fez o
  Godot importar as imagens do .xcarchive). Identidade de assinatura "Apple Development" também na
  Release: com "Apple Distribution" + assinatura automática o Archive falha ("conflicting
  provisioning settings"); o Mac só tem certificados de desenvolvimento e o Organizer do Xcode assina
  para a loja na hora de distribuir. Textos de câmera/microfone/fotos preenchidos ("does not use"):
  vazios dão "Missing purpose string" no envio. Passos: `Godot --headless --path . --export-release
  "iOS" ~/Builds/nephelia_ios/Nephelia.ipa`, depois `xcodebuild -project Nephelia.xcodeproj -scheme
  Nephelia -sdk iphoneos -configuration Release -destination generic/platform=ios archive
  -allowProvisioningUpdates -archivePath ~/Builds/nephelia_ios/Nephelia.xcarchive`, `open` no
  .xcarchive e o usuário faz Distribute App > App Store Connect. Subir o `version` a cada envio.
  EXPORTAR PELO EDITOR REGRAVA O `export_presets.cfg` com o que está na memória dele.
- O `ViewModel` troca os materiais dos braços e da arma por foscos (`_prepare_meshes`): o clarão do
  tiro fica de fora (senão vira um quadrado preto; achado nos prints da loja; teste C40).
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
  - Git: commits na `main`, com push para https://github.com/ItsJuniorDias/nephelia (remoto SSH
    `origin`; `gh` não está instalado). Em 2026-09-22 o repositório foi criado PÚBLICO; o combinado
    era privado (usuário avisado para trocar em Settings).
  - Assets: 12 pacotes gratuitos baixados (506 MB) em `~/Downloads/nephelia_assets/` (kenney/,
    quaternius/, weapons/), registrados em `CREDITS.md`, ainda não importados no projeto.
    Downtown City e Nature têm pasta glTF; a Animation Library tem `Unreal-Godot` (.glb);
    as armas são só FBX. Pendentes (aprovar antes de baixar): Sonniss GDC 2026 (7,5 GB),
    músicas do Kevin MacLeod (CC-BY), fontes Limelight e Josefin Sans.
  - Tarefa 2 (revólver) feita: 26 testes passando.
  - Tarefa 3 (vida, morte e respawn) feita: 31 testes passando.
  - Tarefa 4 (partida todos contra todos) feita: 37 testes passando.
  - Tarefa 5 (bots) feita: 37 testes de controles + 8 de bots passando. Arena com 3 bots
    (Hazel, Otis, Mabel) + jogador.
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
  - Áudio no iPhone: `audio/general/ios/session_category = 3` (Playback). Com o padrão
    ("Ambient") o jogo fica mudo com o iPhone no silencioso.
  - Poderes (Tarefa 8 parte 2): começados e REMOVIDOS a pedido do usuário (2026-09-22); estão no
    histórico do Git se um dia voltarem.
  - Arma sumida no iPhone: resolvida montando a arma em código (ver notas técnicas). Confirmado
    no aparelho pelo usuário.
  - Fontes: Limelight (títulos) e Josefin Sans (interface), do Google Fonts (OFL), aplicadas ao
    jogo inteiro pelo tema.
  - Tarefa 9, parte 1 (menus) feita: menu inicial (jogar, dificuldade, opções, sair), pausa e
    opções salvas no aparelho (sensibilidade, tamanho dos botões, volume). A cena principal
    agora é o menu. 39 + 8 + 10 + 5 + 6 testes passando.
  - Tarefa 9, parte 2 (arte) feita: menus com o kit Art Déco (molduras douradas e mármore),
    controles de toque com a arte e os ícones da Kenney, botão de pausa na tela, barra de vida e
    balas desenhadas no lugar do texto. 39 + 8 + 10 + 5 + 6 testes passando.
  - Tarefa 8, parte 3 (armas extras) feita: repetidora e espingarda como itens, munição contada,
    duas mãos na arma (IK), coice/recarga/som por arma, bots pegam arma perto. Revólver mantido
    como na 1ª versão, a pedido do usuário. 39 + 8 + 10 + 10 + 6 testes passando.
  - Roupas dos personagens feitas: roupa de trabalhador (Peasant, Quaternius, CC0), cabeça
    ORIGINAL do corpo (pedido do usuário), cabelos com cor, barba e chapéus de época feitos em
    código. Pescoço entra na gola sem vão. Por fim (pedido do usuário) os bots vestem só a roupa,
    com a mesma cabeça careca e colorida de antes; o jogador usa boina.
    39 + 8 + 12 + 10 + 6 testes passando.
  - Tarefa 10 (áudio) feita: passos por tipo de chão, recargas, trilho, vento, interface e
    ragtime em domínio público. O tiro continua o sintetizado (o usuário não gostou dos gravados). 39 + 8 + 12 + 10 + 6 + 7 testes passando.
  - Ícone do jogo (emblema Art Déco, gerado com `tools/make_icon.py`) aplicado.
  - Polish com o que é grátis (pedido do usuário, 2026-09-23), etapa 1 feita: efeitos visuais
    (fumaça, faíscas, poeira, marcas de tiro, nuvem ao sumir, anel ao nascer, faíscas no trilho).
    Etapa 2 (aprovada pelo usuário com vídeo): cabeça, cabelo e chapéu presos ao esqueleto (antes
    ficavam parados no ar) e pernas virando para o lado da caminhada. 39 + 8 + 18 + 10 + 6 + 7
    testes passando. Etapa 3 (aprovada): armas longas no ombro, 1ª pessoa própria. Etapa 4
    (aprovada): pegada do revólver calculada (cabo no punho, indicador no gatilho) e mira calibrada.
    39 + 8 + 18 + 11 + 6 + 7 testes passando. Etapa 5 (aprovada): interface inteira com o Marble
    and Gold UI Kit (pago, comprado pelo usuário). Jogo só em inglês. Grama do parque pintada à mão
    com capim e flores. Céu da tarde à noite (pôr do sol, estrelas, nebulosa, lua, postes acesos,
    nuvens andando), aprovado pelo usuário. 39 + 8 + 20 + 11 + 6 + 7 testes passando.
    Próximas: começo e fim do pulo; depois Tarefa 11 (desempenho no iPhone).
  - Multiplayer (pedido do usuário, 2026-09-23), etapa 1 feita: rede com anfitrião-servidor
    (Wi-Fi local; a sala aparece sozinha e começa sozinha quando alguém entra), previsão,
    compensação do atraso, bots completando vagas e etiquetas de nome (gente x bot).
    39 + 8 + 20 + 11 + 9 + 7 + 20 testes passando (a suíte nova é `test_net`).
  - Publicação na App Store começada (2026-09-23): créditos no jogo, versão 1.0, prints e textos
    da loja, vídeos de prévia (iPhone e iPad), páginas de suporte e privacidade. O app já existe no
    App Store Connect (Apple ID 6815422218) com textos, prints e vídeos. 40 + 8 + 20 + 11 + 10 + 7
    + 20 testes. Preset iOS corrigido e build 1.0 (1) arquivado em 2026-09-24 (ver "Build da loja").
    Falta (usuário): upload pelo Organizer, licença do Marble and Gold
    UI Kit (autora iuliana-u), repositório privado, publicar suporte e política (Notion) e colar os
    links, contrato de apps pagos (banco e impostos), preço, classificação etária, Archive e upload
    no Xcode (build de release), TestFlight, enviar para revisão. Próximo: testar Mac + iPhone na mesma Wi-Fi; depois o Game Center (o usuário
    confirma se tem o Apple Developer pago e aprova baixar o GodotApplePlugins).
  - Assets pagos (2026-09-23): o usuário comprou o Universal Animation Library Pro; personagens
    correm nas 8 direções com o tronco firme na mira (aprovado com vídeo). Ordem recomendada do
    resto: Downtown City MegaKit Source (janelas com "sala dentro"), Impact VFX e Muzzle Flash VFX
    (Binbun), roupas (só se servirem para 1900).
  - Cidade com o Downtown City MegaKit [Source] (2026-09-24, aprovado com vídeo): janelas com sala
    que acendem à noite, desgaste nos materiais, prédios de estilos diferentes (banco, hotel, pub,
    cortiço, padaria, Jade Garden, Carmine's), letreiros, toldos, escadas de incêndio, portais nas
    pontes e ilhas no horizonte. Vai na versão 1.1 (a 1.0 já foi arquivada antes disso).
  - Sons de meme (2026-09-24, aprovado com vídeo): 19 sons (15 sintetizados + 4 trechos CC0 do
    Freesound) ligados aos momentos da partida, opção FUNNY SOUNDS nas Opções.
  - Próximo: seguir o polish; depois Tarefa 11 (desempenho no iPhone) ou o que o usuário pedir.
