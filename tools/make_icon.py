#!/usr/bin/env python3
"""Ícone do jogo gerado por IA: OpenRouter + Nano Banana (Google Gemini 2.5 Flash Image).

    python3 tools/make_icon.py refs                   # fotos do jogo usadas como referência de estilo
    python3 tools/make_icon.py generate               # 1 opção de cada ideia (rail, island, emblem, revolver)
    python3 tools/make_icon.py generate rail -n 3     # 3 opções só da ideia "rail"
    python3 tools/make_icon.py generate island --note "sunset colors"
    python3 tools/make_icon.py use <opção.png>        # vira o ícone do jogo (iOS + projeto)

Chave da API: variável OPENROUTER_API_KEY ou arquivo `.env` na raiz do projeto
(`OPENROUTER_API_KEY=sk-or-...`; o `.env` está no .gitignore e o Godot não exporta arquivo oculto).
Custo: uns US$ 0,04 por imagem (o script mostra o custo que o OpenRouter devolve).

As opções geradas ficam FORA do projeto (~/Downloads/nephelia_assets/icon/candidates/), cada uma
com um .json do lado (modelo, prompt, custo). Só a escolhida entra, em ui/icon/app_icon.png
(1024 x 1024, sem transparência, que é o que a App Store exige). Imagem gerada por IA: declarar
no formulário da Steam (ver CREDITS.md).
Usa só Python puro e o `sips` do macOS.
"""

import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(os.path.expanduser("~"), "Downloads", "nephelia_assets", "icon")
REFS = os.path.join(WORK, "refs")
CANDIDATES = os.path.join(WORK, "candidates")
GODOT = os.path.join(os.path.expanduser("~"), "Downloads", "Godot.app", "Contents", "MacOS", "Godot")

ICON_RES = "res://ui/icon/app_icon.png"
ICON_FILE = os.path.join(PROJECT, "ui", "icon", "app_icon.png")
ICON_SIZE = 1024

MODEL = "google/gemini-2.5-flash-image"
IMAGES_URL = "https://openrouter.ai/api/v1/images"
CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"

# Regras de todo ícone de celular (o sistema arredonda os cantos; a App Store recusa transparência).
BASE = (
    "Mobile game app icon for a fast first-person arena shooter set in an original floating city "
    "from the early 1900s: brick and pale stone buildings with slate mansard roofs and dormer windows, "
    "floating above a sea of white clouds and linked by golden brass sky-rails that players ride on hooks. "
    "Art style: stylized low-poly 3D with clean simple shapes and soft sunlight, matching the reference "
    "screenshots from the game (same buildings, colors and character outfit) but more polished and dramatic. "
    "Icon rules: square composition filling the whole canvas edge to edge, ONE bold central subject with a "
    "clear silhouette that still reads at 60x60 pixels, strong contrast, rich warm palette (brass gold, "
    "brick red, sky blue, cloud white). Keep important details away from the corners (they get rounded). "
    "No text, no letters, no numbers, no logo, no watermark, no border, no frame, no rounded corners, "
    "no transparency."
)

# Ideias de ícone: prompt + fotos de referência que ajudam cada uma.
CONCEPTS = {
    "rail": {
        "prompt": "A young worker in a grey flat cap, cream shirt and dark brown trousers (like the reference "
                  "character) sliding fast along a golden brass sky-rail, hanging from a hook with one raised arm "
                  "and aiming an old six-shot revolver forward with the other hand. Dynamic low angle, motion, "
                  "the floating city and clouds below him, bright blue sky behind.",
        "refs": ["ref_personagem.png", "ref_cidade.png"],
    },
    "island": {
        "prompt": "A single floating city island seen from slightly above, like a diorama: a tight cluster of "
                  "early-1900s brick and pale stone buildings with slate mansard roofs on a rocky base, golden "
                  "sky-rails curving around it, puffy clouds underneath, glowing late-afternoon light.",
        "refs": ["ref_cidade.png"],
    },
    "emblem": {
        "prompt": "A bold Art Deco medallion in polished brass: a classic six-shot revolver crossed with a "
                  "sky-rail hook, over a golden sunburst and stylized clouds, on a deep teal-blue background "
                  "with a soft glow. Symmetrical, clean, iconic.",
        "refs": [],
    },
    "revolver": {
        "prompt": "Close-up of a classic early-1900s six-shot revolver with a steel barrel and wooden grip, held "
                  "in a hand and pointing slightly toward the viewer, a small muzzle flash, the floating brick "
                  "city with mansard roofs and golden sky-rails softly blurred in the background above the clouds.",
        "refs": ["ref_cidade.png"],
    },
}


def api_key():
    key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    env_file = os.path.join(PROJECT, ".env")
    if not key and os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                match = re.match(r"\s*(?:export\s+)?OPENROUTER_API_KEY\s*=\s*['\"]?([^'\"\s]+)", line)
                if match:
                    key = match.group(1)
    if not key:
        sys.exit("Falta a chave do OpenRouter: crie o arquivo .env na raiz do projeto com a linha\n"
                 "  OPENROUTER_API_KEY=sk-or-...\n(ou exporte a variável OPENROUTER_API_KEY).")
    return key


def data_url(path):
    mime = "image/png" if path.lower().endswith(".png") else "image/jpeg"
    with open(path, "rb") as f:
        return "data:%s;base64,%s" % (mime, base64.b64encode(f.read()).decode("ascii"))


def post(url, key, payload):
    request = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), method="POST", headers={
        "Authorization": "Bearer " + key,
        "Content-Type": "application/json",
        "X-Title": "Nephelia icon tool",
    })
    try:
        with urllib.request.urlopen(request, timeout=240) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", "replace")
        raise RuntimeError("HTTP %d em %s: %s" % (error.code, url, body[:800])) from None


def request_image(key, model, prompt, refs):
    """Pede UMA imagem. Devolve (bytes, extensão, custo em US$ ou None)."""
    references = [{"type": "image_url", "image_url": {"url": data_url(r)}} for r in refs]
    payload = {"model": model, "prompt": prompt, "aspect_ratio": "1:1", "n": 1}
    if references:
        payload["input_references"] = references
    try:
        result = post(IMAGES_URL, key, payload)
        image = result["data"][0]
        ext = ".jpg" if "jpeg" in image.get("media_type", "") else ".png"
        return base64.b64decode(image["b64_json"]), ext, result.get("usage", {}).get("cost")
    except (RuntimeError, KeyError, IndexError) as error:
        print("  API de imagens falhou (%s); tentando pelo chat." % str(error)[:200])
    # Caminho antigo do OpenRouter: chat com saída de imagem.
    content = [{"type": "text", "text": prompt}] + references
    result = post(CHAT_URL, key, {
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "modalities": ["image", "text"],
        "image_config": {"aspect_ratio": "1:1"},
    })
    url = result["choices"][0]["message"]["images"][0]["image_url"]["url"]
    header, encoded = url.split(",", 1)
    ext = ".jpg" if "jpeg" in header else ".png"
    return base64.b64decode(encoded), ext, result.get("usage", {}).get("cost")


def cmd_refs(_args):
    """Tira as fotos de referência com o Godot (precisa abrir uma janela)."""
    os.makedirs(REFS, exist_ok=True)
    subprocess.run([GODOT, "--path", PROJECT, "-s", "res://tools/icon_reference.gd",
                    "--resolution", "1024x1024", "--always-on-top", "--", REFS], check=True)
    for name in sorted(os.listdir(REFS)):
        print("  " + os.path.join(REFS, name))


def cmd_generate(args):
    names = args.concepts or list(CONCEPTS)
    for name in names:
        if name not in CONCEPTS:
            sys.exit("Ideia desconhecida: %s (opções: %s)" % (name, ", ".join(CONCEPTS)))
    key = None if args.dry_run else api_key()
    os.makedirs(CANDIDATES, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    total_cost = 0.0
    for name in names:
        concept = CONCEPTS[name]
        prompt = BASE + "\n\nScene: " + concept["prompt"]
        if args.note:
            prompt += "\n\nAlso: " + args.note
        refs = [] if args.no_refs else [os.path.join(REFS, r) for r in concept["refs"]
                                        if os.path.exists(os.path.join(REFS, r))]
        for i in range(args.count):
            print("%s %d/%d (%d referência(s))..." % (name, i + 1, args.count, len(refs)))
            if args.dry_run:
                print(prompt)
                continue
            try:
                image, ext, cost = request_image(key, args.model, prompt, refs)
            except Exception as error:  # segue para a próxima: uma falha não perde as outras
                print("  ERRO: %s" % error)
                continue
            path = os.path.join(CANDIDATES, "%s_%s_%d%s" % (name, stamp, i + 1, ext))
            with open(path, "wb") as f:
                f.write(image)
            with open(os.path.splitext(path)[0] + ".json", "w") as f:
                json.dump({"model": args.model, "concept": name, "prompt": prompt, "cost_usd": cost,
                           "references": [os.path.basename(r) for r in refs], "created": stamp}, f, indent=1)
            total_cost += cost or 0.0
            print("  %s%s" % (path, "  (US$ %.3f)" % cost if cost else ""))
    if not args.dry_run:
        print("Custo total: US$ %.3f" % total_cost)


def sips_info(path):
    output = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", path],
                            check=True, capture_output=True, text=True).stdout
    width = int(re.search(r"pixelWidth: (\d+)", output).group(1))
    height = int(re.search(r"pixelHeight: (\d+)", output).group(1))
    return width, height, "hasAlpha: yes" in output


def cmd_use(args):
    source = os.path.abspath(os.path.expanduser(args.image))
    if not os.path.exists(source):
        sys.exit("Arquivo não encontrado: " + source)
    os.makedirs(os.path.dirname(ICON_FILE), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        work = os.path.join(tmp, "icon.png")
        subprocess.run(["sips", "-s", "format", "png", source, "--out", work], check=True, capture_output=True)
        width, height, alpha = sips_info(work)
        if width != height:
            # Recorta o quadrado do meio.
            side = min(width, height)
            subprocess.run(["sips", "-c", str(side), str(side), work], check=True, capture_output=True)
        if alpha:
            # A App Store recusa ícone com transparência: passa por JPEG (qualidade máxima) e volta.
            flat = os.path.join(tmp, "flat.jpg")
            subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "100", work, "--out", flat],
                           check=True, capture_output=True)
            subprocess.run(["sips", "-s", "format", "png", flat, "--out", work], check=True, capture_output=True)
        subprocess.run(["sips", "-z", str(ICON_SIZE), str(ICON_SIZE), work], check=True, capture_output=True)
        shutil.copyfile(work, ICON_FILE)
    width, height, alpha = sips_info(ICON_FILE)
    print("Ícone: %s (%d x %d, transparência: %s)" % (os.path.relpath(ICON_FILE, PROJECT), width, height,
                                                       "sim" if alpha else "não"))
    # Guarda de onde veio (prompt e modelo), para os créditos e o formulário da Steam.
    sidecar = os.path.splitext(source)[0] + ".json"
    if os.path.exists(sidecar):
        shutil.copyfile(sidecar, os.path.join(WORK, "app_icon_source.json"))

    _set_line(os.path.join(PROJECT, "export_presets.cfg"), r'^icons/icon_1024x1024=.*$',
              'icons/icon_1024x1024="%s"' % ICON_RES)
    _set_line(os.path.join(PROJECT, "project.godot"), r'^config/icon=.*$', 'config/icon="%s"' % ICON_RES)
    editor = subprocess.run(["pgrep", "-f", "Godot.*--editor"], capture_output=True, text=True).stdout.strip()
    if editor:
        print("O editor do Godot está aberto: feche com Cmd+Q e abra de novo (senão ele pode desfazer "
              "a troca no project.godot / export_presets.cfg).")


def _set_line(path, pattern, line):
    with open(path) as f:
        text = f.read()
    new_text, count = re.subn(pattern, line, text, flags=re.M)
    if count == 0:
        print("  AVISO: %s não tem a linha %s" % (os.path.basename(path), pattern))
        return
    with open(path, "w") as f:
        f.write(new_text)
    print("  %s: %s" % (os.path.basename(path), line))


def main():
    parser = argparse.ArgumentParser(description="Ícone do Nephelia com OpenRouter + Nano Banana.")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("refs", help="fotos do jogo para referência de estilo").set_defaults(func=cmd_refs)
    generate = sub.add_parser("generate", help="gera opções de ícone")
    generate.add_argument("concepts", nargs="*", help="ideias: " + ", ".join(CONCEPTS) + " (padrão: todas)")
    generate.add_argument("-n", "--count", type=int, default=1, help="opções por ideia")
    generate.add_argument("--note", help="pedido extra (em inglês), somado ao prompt")
    generate.add_argument("--model", default=MODEL)
    generate.add_argument("--no-refs", action="store_true", help="não mandar as fotos do jogo")
    generate.add_argument("--dry-run", action="store_true", help="só mostra os prompts, sem chamar a API")
    generate.set_defaults(func=cmd_generate)
    use = sub.add_parser("use", help="transforma uma opção no ícone do jogo")
    use.add_argument("image")
    use.set_defaults(func=cmd_use)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
