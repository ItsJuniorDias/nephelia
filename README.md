<p align="center">
  <img src="ui/icon/app_icon.png" width="140" alt="Ícone do Nephelia: revólveres cruzados, gancho e sol Art Déco">
</p>

<h1 align="center">Nephelia</h1>

<p align="center">
  <b>Arena in the Clouds</b><br>
  Tiro em primeira pessoa, rápido e frenético, para celular, numa cidade flutuante do começo do século XX.
</p>

<p align="center">
  <img alt="Godot 4.7.2" src="https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white">
  <img alt="GDScript" src="https://img.shields.io/badge/GDScript-tipagem%20est%C3%A1tica-355570">
  <img alt="iOS e Android" src="https://img.shields.io/badge/plataformas-iOS%20%C2%B7%20Android-6b6b6b">
  <img alt="Steam planejado" src="https://img.shields.io/badge/Steam-planejado-1b2838?logo=steam&logoColor=white">
</p>

![Tiroteio no pôr do sol, na praça central da Sky Plaza](docs/images/gameplay_sunset.jpg)

## O jogo

Partidas curtas de todos contra todos sobre três quarteirões de cidade que flutuam acima de um mar
de nuvens. Quem cai da ilha, morre. Quem fica, atira, pega o gancho e desce pelos trilhos aéreos
para cair em cima de alguém do outro lado.

- **Partidas rápidas:** 5 minutos ou 15 abates. Sempre há 4 personagens na arena: os bots
  completam as vagas, e quem entra toma o lugar de um bot.
- **Sky Plaza:** uma praça central e dois bairros, um de casas com parque e um de lojas, com
  banco, hotel, pub, padaria e cortiços de tijolo. Pontes ligam os três quarteirões, e outras
  ilhas aparecem no horizonte.
- **Trilhos aéreos:** perto de um trilho aparece o botão do gancho. O personagem engata,
  desliza pendurado e solta onde quiser.
- **Armas:** o revólver está sempre na mão. A repetidora e a espingarda aparecem como itens na
  arena, junto com frascos de tônico que devolvem vida.
- **Bots** em três dificuldades. Eles enxergam, perseguem, desviam da borda, buscam vida e armas
  e usam os trilhos, com os mesmos comandos do jogador (sem trapaça).
- **Da tarde à noite:** a luz segue o relógio da partida, do sol dourado ao pôr do sol e à noite
  estrelada. Postes e janelas acendem.
- **Multiplayer até 4 pessoas:** no mesmo Wi-Fi (a sala aparece sozinha, sem digitar endereço)
  ou online pelo botão **PLAY ONLINE**, com iPhone, Android e computador na mesma partida.
- **FUNNY SOUNDS:** sons de meme feitos pelo projeto para os momentos da partida. Dá para
  desligar nas opções.
- O texto do jogo é só em inglês.

<p align="center">
  <img src="docs/images/main_menu.jpg" width="720" alt="Menu inicial com o monumento Art Déco">
</p>

## Situação

| Plataforma | Situação |
|---|---|
| iPhone e iPad | Versão 1.0 arquivada para a App Store (jogo pago). A 1.1 traz a cidade nova, as corridas em 8 direções, os sons de meme e o online. |
| Android | APK de teste (preset "Android"). Google Play depois. |
| Mac | Desenvolvimento e testes. |
| Steam (Windows, Mac, Linux) | Planejado. Falta o modo de controle de PC. |

O plano completo, com o que já foi feito e o que falta, está no [PLANO.md](PLANO.md).

## Controles

| Ação | Toque | Teclado e mouse | Controle |
|---|---|---|---|
| Andar | Joystick à esquerda (aparece onde o dedo toca) | `W` `A` `S` `D` ou setas | Analógico esquerdo |
| Olhar | Arrastar no resto da tela | Mouse | Analógico direito |
| Atirar | Botão da mira | Botão esquerdo do mouse | Gatilho direito |
| Pular | Botão de seta dupla | `Espaço` | `A` |
| Recarregar | Botão de recarga | `R` | `X` |
| Gancho do trilho | Botão da mão (só aparece com um trilho ao alcance) | `E` | `Y` |
| Pausa | Botão de pausa | `Esc` | `Start` |

No toque e no controle a mira dá uma pequena ajuda. Todo comando passa pelo Input Map do Godot,
nunca por tecla fixa.

## Rodando o projeto

1. Instale o **Godot 4.7.2** (versão padrão, sem .NET).
2. Abra o `project.godot` e aperte **F5**. O jogo começa no menu.

No Mac o projeto vem com *Emulate Touch From Mouse* ligado, para testar os controles de toque
com o mouse. Para testar o multiplayer numa máquina só, use **Debug → Customize Run Instances**
com 2 janelas: uma hospeda e a outra entra (a sala aparece sozinha).

Tecnologia: Godot 4.7.2, GDScript com tipagem estática, física Jolt e renderizador Mobile.

## Testes

São 7 suítes de testes automáticos sem tela (121 testes). Saída 0 = tudo passou.

```bash
GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot
for suite in test_controls test_bots test_arena test_items test_menus test_audio test_net; do
  "$GODOT" --headless --path . -s "res://tests/$suite.gd" || echo "FALHOU: $suite"
done
```

A suíte `test_net` abre outros processos do Godot para jogar em rede de verdade. Os testes
ponta a ponta do online (N22 e N23) precisam do Node.js 24 e do repositório do servidor clonado
ao lado deste (`../nephelia-server`); sem eles, esses dois testes são pulados.

## Multiplayer e online

- **Mesmo Wi-Fi:** um aparelho hospeda e é o servidor da partida (ENet, UDP). Os outros acham a
  sala sozinhos: o jogo pergunta endereço por endereço da rede local.
- **Online:** o botão PLAY ONLINE pede uma partida ao matchmaker, que roda no Render. A partida
  em si é o próprio jogo rodando sem tela (servidor dedicado), e a conexão vai por WebSocket.
- **O mesmo nos dois modos:** protocolo próprio (comandos 60 vezes por segundo, foto do estado
  30 vezes por segundo), previsão do próprio movimento, compensação do atraso nos tiros e bots
  completando as vagas.

O matchmaker fica num repositório separado:
[nephelia-server](https://github.com/ItsJuniorDias/nephelia-server) (Node.js + TypeScript).

> **Versão da rede:** `NetMessage.VERSION` (em `net/net_message.gd`) sobe sempre que o protocolo
> **ou a arena** mudar, junto com o `protocolVersion` do servidor. Aparelhos com versões
> diferentes não jogam juntos: para jogar, os dois precisam do mesmo build.

## Exportando

Exporte com o editor **fechado**: exportar pelo editor regrava o `export_presets.cfg` com o que
está na memória dele. Nos comandos, `$GODOT` é o executável do Godot (como na seção Testes).

**iOS** (Xcode e conta Apple Developer): o preset gera só o projeto do Xcode, fora da pasta do jogo.

```bash
"$GODOT" --headless --path . --export-release "iOS" ~/Builds/nephelia_ios/Nephelia.ipa
cd ~/Builds/nephelia_ios
xcodebuild -project Nephelia.xcodeproj -scheme Nephelia -sdk iphoneos -configuration Release \
  -destination generic/platform=ios archive -allowProvisioningUpdates \
  -archivePath ~/Builds/nephelia_ios/Nephelia.xcarchive
open Nephelia.xcarchive   # Distribute App > App Store Connect
```

**Android** (OpenJDK 17 e Android SDK; caminhos em *Editor Settings → Export → Android*):

```bash
"$GODOT" --headless --path . --export-debug "Android" ~/Builds/nephelia_android/Nephelia.apk
```

O preset precisa das permissões **Internet**, **Access Network State** e **Access Wifi State**.
Sem a de Internet, o Android bloqueia toda conexão sem avisar (nem o online nem o Wi-Fi
funcionam).

**Servidor das partidas online** (preset "Linux Server": o jogo sem arte, só a lógica):

```bash
"$GODOT" --headless --path . --export-pack "Linux Server" ../nephelia-server/game/nephelia_server.pck
```

Depois faça commit no `nephelia-server`, a cada mudança de rede ou de partida: o servidor
precisa ter o mesmo código dos jogadores.

## Ferramentas

Boa parte do conteúdo é gerada por scripts em `tools/` (rodar com `Godot --path . -s <script>`;
cada um explica o uso no cabeçalho).

| Script | O que faz |
|---|---|
| `build_skyplaza.gd` | Monta a arena inteira em código: quarteirões, pontes, trilhos, itens, nuvens e horizonte |
| `city_kit.gd` | Monta as fachadas dos prédios peça por peça (Downtown City MegaKit) |
| `bake_navmesh.gd` | Calcula a malha de navegação dos bots (rodar de novo ao mudar o mapa) |
| `bake_characters.gd`, `bake_weapons.gd` | Preparam o corpo dos personagens e as malhas das armas |
| `extract_bot_animations.gd` | Extrai as animações usadas da Universal Animation Library |
| `make_menus.gd`, `make_theme.gd` | Montam as telas e o tema da interface |
| `prepare_sounds.py`, `make_meme_sounds.py` | Preparam os sons e sintetizam os sons de meme |
| `store_screenshots.gd`, `app_preview.gd` | Prints e vídeo de prévia da App Store, no tamanho exato |
| `*_sheet.gd` | Folhas de fotos para conferir personagens, poses, efeitos, céu, cidade e interface |

## Estrutura de pastas

```
assets/       arquivos de terceiros (modelos, texturas, sons, fontes, interface)
audio/        sons do jogo e sons de meme
autoload/     opções salvas no aparelho (Settings)
bots/         controlador e dificuldades dos bots
characters/   personagem, modelo, roupas, animações e efeitos
items/        itens da arena (tônicos e armas)
levels/       arena Sky Plaza, céu, navegação
match/        juiz da partida e modo todos contra todos
net/          multiplayer: Wi-Fi, online, servidor dedicado
player/       controlador do jogador (toque, teclado e controle)
rails/        trilhos aéreos
store/        textos da App Store, política de privacidade e suporte
tests/        testes automáticos
tools/        geradores e ferramentas de conferência
ui/           menus, HUD, sala, créditos, tema e ícone
vfx/          efeitos visuais
weapons/      armas, tiro e braços em primeira pessoa
docs/         imagens deste README (ignorada pelo Godot)
```

## Documentação

- [CLAUDE.md](CLAUDE.md): notas técnicas detalhadas (como cada sistema funciona e as armadilhas
  já encontradas) e o estado do projeto.
- [PLANO.md](PLANO.md): tarefas e roadmap.
- [CREDITS.md](CREDITS.md): todos os assets de terceiros, com autor, licença e link.
- [store/](store/): textos da loja, política de privacidade e página de suporte.

## Créditos

Feito por Alexandre de Paula Dias Junior.

Assets de terceiros (lista completa no [CREDITS.md](CREDITS.md) e na tela de créditos do jogo):

- **Quaternius** (CC0): Downtown City MegaKit, Stylized Nature MegaKit, Universal Base
  Characters, Universal Animation Library e Modular Character Outfits.
- **Kenney** (CC0): controles de toque, partículas e sons de interface.
- **LowPolyAssets** (CC0): Low Poly Wild West Guns.
- **JulioVII** (CC-BY): textura da grama do parque.
- **iuliana-u**: Marble and Gold UI Kit (pago).
- **Fontes** Limelight e Josefin Sans (SIL OFL), do Google Fonts.
- **Sons** CC0 do OpenGameArt e do Freesound.
- **Música:** *Maple Leaf Rag*, de Scott Joplin, em gravações de domínio público.
- O ícone do jogo foi gerado por IA (declarado no CREDITS.md).

## Licença

O código e o conteúdo próprio do Nephelia não têm licença de código aberto: todos os direitos
reservados ao autor. Os assets de terceiros seguem as licenças listadas no
[CREDITS.md](CREDITS.md). O Marble and Gold UI Kit é um asset pago, comprado para este jogo.
