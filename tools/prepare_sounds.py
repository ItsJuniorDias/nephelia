#!/usr/bin/env python3
"""Prepara os sons do jogo a partir dos downloads brutos (fora do projeto).

    python3 tools/prepare_sounds.py

Fontes (ver CREDITS.md): ~/Downloads/nephelia_assets/audio/ e ~/Downloads/nephelia_assets/kenney/.
Cada tiro da Free Firearm Sound Library tem 8 a 12 s (96 kHz, 24 bits, estéreo, com eco longo):
aqui ele é recortado no disparo, com a cauda curta e um fade no fim, vira mono (o jogo toca em 3D)
e 44,1 kHz / 16 bits, com o pico normalizado. O chiado do trilho é sintetizado aqui mesmo.
Usa só o que vem no macOS (afconvert) e Python puro.
"""

import array
import math
import os
import random
import shutil
import subprocess
import tempfile
import wave
import zipfile

HOME = os.path.expanduser("~")
RAW = os.path.join(HOME, "Downloads", "nephelia_assets")
FIREARMS = os.path.join(RAW, "audio", "opengameart", "ffl", "Prepared SFX Library")
OGA = os.path.join(RAW, "audio", "opengameart")
MUSIC = os.path.join(RAW, "audio", "music")
KENNEY_IMPACT = os.path.join(RAW, "kenney", "kenney_impact-sounds.zip")
KENNEY_INTERFACE = os.path.join(RAW, "kenney", "kenney_interface-sounds.zip")

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_SFX = os.path.join(PROJECT, "assets", "audio", "sfx")
OUT_MUSIC = os.path.join(PROJECT, "assets", "audio", "music")
RATE = 44100


def to_mono_16(source):
    """Converte com o afconvert (44,1 kHz, 16 bits, mono) e devolve as amostras."""
    with tempfile.TemporaryDirectory() as tmp:
        target = os.path.join(tmp, "out.wav")
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@%d" % RATE, "-c", "1", source, target],
                       check=True)
        with wave.open(target, "rb") as w:
            samples = array.array("h", w.readframes(w.getnframes()))
    return [s / 32768.0 for s in samples]


def write(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = array.array("h", [max(-32767, min(32767, int(round(s * 32767.0)))) for s in samples])
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("  %s (%.2f s)" % (os.path.relpath(path, PROJECT), len(samples) / RATE))


def normalize(samples, peak_db=-1.0):
    peak = max(abs(s) for s in samples) or 1.0
    gain = (10.0 ** (peak_db / 20.0)) / peak
    return [s * gain for s in samples]


def onset(samples, threshold=0.08):
    """Primeira amostra acima de `threshold` do pico (o disparo)."""
    peak = max(abs(s) for s in samples) or 1.0
    for i, s in enumerate(samples):
        if abs(s) >= peak * threshold:
            return i
    return 0


def shot(source, target, length, fade):
    """Recorta um tiro: do disparo até `length` s, com fade-out nos últimos `fade` s."""
    samples = to_mono_16(source)
    start = max(0, onset(samples) - int(0.004 * RATE))
    cut = samples[start:start + int(length * RATE)]
    fade_len = int(fade * RATE)
    for i in range(fade_len):
        k = len(cut) - fade_len + i
        if 0 <= k < len(cut):
            # Curva de cosseno: some sem estalo.
            cut[k] *= 0.5 + 0.5 * math.cos(math.pi * i / fade_len)
    write(target, normalize(cut))


def trimmed(source, target, peak_db=-1.0):
    """Tira o silêncio do começo e do fim (recargas)."""
    samples = to_mono_16(source)
    start = max(0, onset(samples, 0.02) - int(0.01 * RATE))
    end = len(samples) - onset(list(reversed(samples)), 0.02) + int(0.05 * RATE)
    write(target, normalize(samples[start:min(end, len(samples))], peak_db))


def rail_loop(target, seconds=2.0):
    """Chiado da roldana no cabo: ruído filtrado + um zumbido metálico, em loop perfeito.

    As frequências são múltiplos de 1/seconds (ciclos inteiros no loop) e o ruído é
    uma soma de senoides desses mesmos múltiplos: começo e fim se encaixam sem estalo.
    """
    random.seed(7)
    count = int(seconds * RATE)
    base = 1.0 / seconds
    partials = []
    # Zumbido: harmônicos de ~220 Hz com vibrato lento.
    for harmonic, amp in [(1, 0.5), (2, 0.28), (3, 0.16), (5, 0.08), (7, 0.05)]:
        partials.append((round(220 * harmonic / base) * base, amp, random.random() * math.tau))
    # "Areia" do cabo: muitas senoides fracas entre 1,5 e 5 kHz.
    for _ in range(160):
        f = round(random.uniform(1500, 5000) / base) * base
        partials.append((f, 0.02, random.random() * math.tau))
    samples = []
    for i in range(count):
        t = i / RATE
        wobble = 1.0 + 0.25 * math.sin(math.tau * 2 * base * t)
        value = 0.0
        for f, amp, phase in partials:
            value += amp * math.sin(math.tau * f * t + phase)
        samples.append(value * wobble)
    write(target, normalize(samples, -3.0))


def copy_from_zip(zip_path, names, folder):
    with zipfile.ZipFile(zip_path) as z:
        entries = {os.path.basename(n): n for n in z.namelist()}
        for name in names:
            target = os.path.join(folder, name)
            os.makedirs(folder, exist_ok=True)
            with z.open(entries[name]) as src, open(target, "wb") as dst:
                shutil.copyfileobj(src, dst)
            print("  %s" % os.path.relpath(target, PROJECT))


def main():
    print("Tiros (Free Firearm Sound Library, CC0):")
    shot(os.path.join(FIREARMS, "Smith & Wesson 642", "V_27P.wav"),
         os.path.join(OUT_SFX, "firearms", "revolver_shot.wav"), 1.1, 0.6)
    shot(os.path.join(FIREARMS, "Model 1894", "L_23P.wav"),
         os.path.join(OUT_SFX, "firearms", "repeater_shot.wav"), 1.5, 0.8)
    shot(os.path.join(FIREARMS, "Model 12", "K_22P.wav"),
         os.path.join(OUT_SFX, "firearms", "shotgun_shot.wav"), 1.7, 0.9)

    print("Recargas e vento (OpenGameArt, CC0):")
    trimmed(os.path.join(OGA, "gunreload1.wav"), os.path.join(OUT_SFX, "opengameart", "revolver_reload.wav"), -3.0)
    trimmed(os.path.join(OGA, "assaultriflereload1.wav"), os.path.join(OUT_SFX, "opengameart", "repeater_reload.wav"), -3.0)
    trimmed(os.path.join(OGA, "shotguncock.wav"), os.path.join(OUT_SFX, "opengameart", "shotgun_reload.wav"), -3.0)
    wind = os.path.join(OUT_SFX, "opengameart", "wind_loop.ogg")
    shutil.copyfile(os.path.join(OGA, "wind_woosh_loop.ogg"), wind)
    print("  %s" % os.path.relpath(wind, PROJECT))

    print("Trilho (sintetizado aqui):")
    rail_loop(os.path.join(OUT_SFX, "nephelia", "rail_slide_loop.wav"))

    print("Kenney (CC0):")
    kenney = os.path.join(OUT_SFX, "kenney")
    copy_from_zip(KENNEY_IMPACT, ["footstep_concrete_%03d.ogg" % i for i in range(5)]
                  + ["footstep_grass_%03d.ogg" % i for i in range(5)]
                  + ["footstep_wood_%03d.ogg" % i for i in range(5)]
                  + ["impactSoft_heavy_000.ogg", "impactSoft_medium_000.ogg", "impactMetal_heavy_000.ogg",
                     "impactPunch_heavy_000.ogg", "impactPunch_medium_000.ogg", "impactBell_heavy_000.ogg"],
                  kenney)
    copy_from_zip(KENNEY_INTERFACE, ["click_002.ogg", "select_001.ogg", "back_001.ogg",
                                     "confirmation_001.ogg", "tick_002.ogg"], kenney)

    print("Música (domínio público):")
    os.makedirs(OUT_MUSIC, exist_ok=True)
    for name in ["maple_leaf_rag_marine_band_1906.ogg", "maple_leaf_rag_piano.ogg"]:
        shutil.copyfile(os.path.join(MUSIC, name), os.path.join(OUT_MUSIC, name))
        print("  %s" % os.path.relpath(os.path.join(OUT_MUSIC, name), PROJECT))


if __name__ == "__main__":
    main()
