# Créditos e licenças de terceiros

Todo asset de terceiros usado no jogo fica registrado aqui. Os arquivos originais baixados
ficam fora do projeto, em `~/Downloads/nephelia_assets/`.

## Modelos 3D e animações

| Asset | Autor | Licença | Link |
|---|---|---|---|
| Downtown City MegaKit [Standard] | Quaternius | CC0 1.0 | https://quaternius.itch.io/downtown-city-megakit |
| Stylized Nature MegaKit [Standard] | Quaternius | CC0 1.0 | https://quaternius.itch.io/stylized-nature-megakit |
| Universal Base Characters [Standard] | Quaternius | CC0 1.0 | https://quaternius.itch.io/universal-base-characters |
| Universal Animation Library [Standard] | Quaternius | CC0 1.0 | https://quaternius.itch.io/universal-animation-library |
| Universal Animation Library [Pro] (corridas nas 8 direções; comprado) | Quaternius | CC0 1.0 | https://quaternius.itch.io/universal-animation-library |
| Modular Character Outfits - Fantasy [Standard] (roupa Peasant) | Quaternius | CC0 1.0 | https://quaternius.itch.io/modular-character-outfits-fantasy |
| Low Poly Wild West Guns | LowPolyAssets | CC0 1.0 | https://lowpolyassets.itch.io/low-poly-guns |

## Texturas

| Asset | Autor | Licença | Link |
|---|---|---|---|
| Stylized Grass & Dirt (textura Stylized_HandpaintedGrass_01: grama do parque) | JulioVII | **CC-BY** (uso comercial liberado, só não pode revender): **crédito obrigatório no jogo** | https://juliovii.itch.io/ftpgrass-dirt |

Reduzida para 1024 px (cor e relevo) em `assets/textures/juliovii/`; o pacote original (4K) fica
em `~/Downloads/nephelia_assets/textures/juliovii/`.

## Interface, efeitos e sons

| Asset | Autor | Licença | Link |
|---|---|---|---|
| Mobile Controls | Kenney | CC0 1.0 | https://kenney.nl/assets/mobile-controls |
| Crosshair Pack | Kenney | CC0 1.0 | https://kenney.nl/assets/crosshair-pack |
| UI Pack | Kenney | CC0 1.0 | https://kenney.nl/assets/ui-pack |
| Particle Pack (fumaça, poeira, brilhos, anel e clarão dos efeitos) | Kenney | CC0 1.0 | https://kenney.nl/assets/particle-pack |
| Impact Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| Interface Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/interface-sounds |
| Prototype Textures | Kenney | CC0 1.0 | https://kenney.nl/assets/prototype-textures |

## Sons de armas, recargas e vento

| Asset | Autor | Licença | Link |
|---|---|---|---|
| The Free Firearm Sound Library (baixado e testado; não usado: o usuário preferiu o tiro sintetizado) | Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney | CC0 1.0 | https://opengameart.org/content/the-free-firearm-sound-library |
| Gun reload sounds | SpringySpringo | CC0 1.0 | https://opengameart.org/content/gun-reload-sounds |
| wind whoosh loop | SketchMan3 | CC0 1.0 | https://opengameart.org/content/wind-whoosh-loop |
| Gunshot Sounds (baixado como reserva; não usado) | OpenGameArt | CC0 1.0 | https://opengameart.org/content/gunshot-sounds |

As recargas foram convertidas para mono e normalizadas por `tools/prepare_sounds.py`.

## Música

| Asset | Autor | Licença | Link |
|---|---|---|---|
| Maple Leaf Rag (Scott Joplin, 1899), gravação de 1906 (menu) | United States Marine Band | Domínio público (obra do governo dos EUA, publicada antes de 1926) | https://commons.wikimedia.org/wiki/File:1906_-_Scott_Joplin's_Maple_Leaf_Rag_(1899)_played_by_the_United_States_Marine_Band.ogg |
| Maple Leaf Rag (Scott Joplin, 1899), piano (partida) | Zachary Brewster-Geisz | Domínio público (doado pelo autor) | https://archive.org/details/MapleLeafRag |

## Interface

| Asset | Autor | Licença | Link |
|---|---|---|---|
| Marble and Gold UI Kit - Strategy Game | iuliana-u | **Pago** (US$ 7, comprado pelo usuário em 2026-09-23). A página e o zip não dizem a licença: confirmar o uso comercial com a autora antes de publicar. | https://iuliana-u.itch.io/marble-and-gold-ui-kit |

Usamos o monumento e a janela do menu inicial, o céu azul, as janelas de mármore, os botões, os
sliders, as etiquetas e faixas do HUD, o anel dos botões de toque e a janela do placar final
(`assets/ui/marble_gold/`; o zip original fica em `~/Downloads/nephelia_assets/ui/`). A página
diz que não usou IA generativa.

O NEI's Art Deco UI Kit (New England Interactive, gratuito) foi usado nos menus até 2026-09-23 e
saiu do projeto quando o Marble and Gold entrou.

## Fontes

| Asset | Autor | Licença | Link |
|---|---|---|---|
| Limelight (títulos) | Ania Kruk / Google Fonts | SIL OFL 1.1 | https://fonts.google.com/specimen/Limelight |
| Josefin Sans (interface) | Santiago Orozco / Google Fonts | SIL OFL 1.1 | https://fonts.google.com/specimen/Josefin+Sans |

As licenças vêm junto em `assets/fonts/*-OFL.txt`, como a OFL exige.

## Criados pelo projeto

| Asset | Observação |
|---|---|
| `assets/audio/sfx/nephelia/revolver_shot_placeholder.wav` | Tiro das três armas, sintetizado por código (sem material de terceiros); cada arma muda o tom |
| `assets/audio/sfx/nephelia/rail_slide_loop.wav` | Chiado da roldana no trilho, sintetizado por `tools/prepare_sounds.py` (sem material de terceiros) |

## Gerados por IA (declarar no formulário da Steam)

| Asset | Como foi feito |
|---|---|
| `ui/icon/app_icon.png` (ícone do jogo) | Google Gemini 2.5 Flash Image ("Nano Banana") pelo OpenRouter, com `tools/make_icon.py` (ideia "emblem", sem imagens de referência), em 2026-09-22. O prompt e o modelo ficam em `~/Downloads/nephelia_assets/icon/app_icon_source.json`. |

CC0 não exige crédito, mas agradecemos aos autores nos créditos do jogo.
