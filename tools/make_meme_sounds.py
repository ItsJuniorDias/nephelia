#!/usr/bin/env python3
"""Prepara os sons de meme do jogo: sintetizados aqui + trechos de gravações CC0.

    python3 tools/make_meme_sounds.py [pasta_da_previa]

Pedido do usuário (2026-09-24): humor com "cara de meme", mas sem os sons originais (trechos de
filmes, jogos, músicas e vozes de gente real não têm licença e o jogo é pago). Cada som aqui é a
NOSSA versão da ideia: o grave dramático, o apito de desenho caindo, o trombone triste etc.
As reações de plateia, a caixa registradora e os grilos são gravações CC0 do Freesound (ver
CREDITS.md), baixadas pelo usuário em ~/Downloads/nephelia_assets/audio/freesound/: daqui sai só
o trecho usado (`RECORDED`).
Saída: assets/audio/sfx/memes/meme_<nome>.wav (mono, 44,1 kHz, 16 bits). Com uma pasta, grava
também <pasta>/meme_board.wav: todos em sequência, para ouvir e aprovar.
Python puro (sem numpy), como o prepare_sounds.py; o afconvert do macOS lê as gravações.
"""

import math
import os
import random
import sys

from prepare_sounds import PROJECT, RAW, RATE, normalize, to_mono_16, write

OUT = os.path.join(PROJECT, "assets", "audio", "sfx", "memes")
FREESOUND = os.path.join(RAW, "audio", "freesound")
TAU = math.tau


# --- Blocos básicos ---

def frames(seconds):
    return int(seconds * RATE)


def silence(seconds):
    return [0.0] * frames(seconds)


def mix_into(target, source, at_seconds=0.0, gain=1.0):
    """Soma `source` em `target` a partir de `at_seconds` (aumenta `target` se precisar)."""
    start = frames(at_seconds)
    end = start + len(source)
    if end > len(target):
        target.extend([0.0] * (end - len(target)))
    for i, value in enumerate(source):
        target[start + i] += value * gain
    return target


def tone(seconds, freq, harmonics=((1, 1.0),), amp=None, vibrato=None, brightness=None):
    """Oscilador por soma de harmônicos. `freq`, `amp` e `brightness` podem ser funções do tempo;
    `brightness` (0..1) apaga os harmônicos altos (1 = todos, perto de 0 = só o fundamental)."""
    out = []
    phase = 0.0
    nyquist = RATE * 0.45
    for i in range(frames(seconds)):
        t = i / RATE
        f = freq(t) if callable(freq) else freq
        if vibrato is not None:
            rate, depth = vibrato(t) if callable(vibrato) else vibrato
            f *= 1.0 + depth * math.sin(TAU * rate * t)
        phase += f / RATE
        b = brightness(t) if callable(brightness) else brightness
        value = 0.0
        for harmonic, weight in harmonics:
            if harmonic * f >= nyquist:
                continue
            if b is not None and harmonic > 1:
                weight *= b ** (harmonic - 1)
            value += weight * math.sin(TAU * harmonic * phase)
        a = amp(t) if callable(amp) else (1.0 if amp is None else amp)
        out.append(value * a)
    return out


def saw_harmonics(count, rolloff=1.0):
    return [(h, 1.0 / h ** rolloff) for h in range(1, count + 1)]


def square_harmonics(count):
    return [(h, 1.0 / h) for h in range(1, count * 2, 2)]


def noise(seconds, seed=1):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(frames(seconds))]


def lowpass(samples, cutoff):
    a = math.exp(-TAU * cutoff / RATE)
    out = []
    y = 0.0
    for x in samples:
        y = (1.0 - a) * x + a * y
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def bandpass(samples, low, high):
    return lowpass(highpass(samples, low), high)


def envelope(samples, attack=0.005, release=0.02, decay=None):
    """Ataque e soltura lineares; `decay` (1/s) = queda exponencial desde o começo."""
    count = len(samples)
    a = max(1, frames(attack))
    r = max(1, frames(release))
    out = []
    for i, x in enumerate(samples):
        g = min(1.0, i / a, (count - i) / r)
        if decay is not None:
            g *= math.exp(-decay * i / RATE)
        out.append(x * g)
    return out


def soft_clip(samples, drive=2.0):
    k = math.tanh(drive)
    return [math.tanh(drive * x) / k for x in samples]


def reverb(samples, wet=0.3, room=0.82, tail=1.5):
    """Reverberação de Schroeder (4 pentes + 2 passa-tudo)."""
    dry = samples + [0.0] * frames(tail)
    combs = []
    for delay in (1557, 1617, 1491, 1422):
        buffer = [0.0] * delay
        out = []
        index = 0
        low = 0.0
        for x in dry:
            y = buffer[index]
            low = y * 0.7 + low * 0.3
            buffer[index] = x + low * room
            index = (index + 1) % delay
            out.append(y)
        combs.append(out)
    mixed = [sum(c[i] for c in combs) * 0.25 for i in range(len(dry))]
    for delay, gain in ((556, 0.5), (225, 0.5)):
        buffer = [0.0] * delay
        out = []
        index = 0
        for x in mixed:
            b = buffer[index]
            y = -x + b
            buffer[index] = x + b * gain
            index = (index + 1) % delay
            out.append(y)
        mixed = out
    return [d + m * wet for d, m in zip(dry, mixed)]


def trim_tail(samples, threshold=0.0015):
    end = len(samples)
    while end > 1 and abs(samples[end - 1]) < threshold:
        end -= 1
    out = samples[:end]
    fade = min(len(out), frames(0.01))
    for i in range(fade):
        out[len(out) - 1 - i] *= i / fade
    return out


def note_hz(name):
    """Nome de nota (ex.: "Bb3", "C#5") em Hz (A4 = 440)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semitone = names[name[0]]
    rest = name[1:]
    if rest[0] in "#b":
        semitone += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 440.0 * 2.0 ** ((semitone + 12 * (int(rest) - 4)) / 12.0)


# --- Os sons ---

def boom():
    """Grave dramático (a ideia do "vine boom"): baque de subgrave que cai de tom, com eco."""
    body = tone(1.8, lambda t: 44.0 + 80.0 * math.exp(-t * 9.0), [(1, 1.0), (2, 0.35), (3, 0.12)],
                amp=lambda t: min(1.0, t / 0.003) * math.exp(-t * 2.0))
    body = envelope(soft_clip(body, 2.6), 0.001, 0.4)
    hit = envelope(lowpass(noise(0.03, 3), 1800), 0.001, 0.02)
    mix_into(body, hit, 0.0, 0.5)
    return reverb(body, wet=0.45, room=0.86, tail=1.2)


def bonk():
    """"Bonk" de desenho: batida oca de madeira que desce de tom."""
    knock = tone(0.35, lambda t: 420.0 * (1.0 + 0.5 * math.exp(-t * 45.0)),
                 [(1, 1.0), (2.72, 0.45), (5.2, 0.18)], amp=lambda t: math.exp(-t * 16.0))
    click = envelope(highpass(noise(0.012, 5), 2500), 0.0005, 0.008)
    mix_into(knock, click, 0.0, 0.35)
    return reverb(envelope(knock, 0.0005, 0.08), wet=0.12, room=0.6, tail=0.3)


def sad_trombone():
    """Trombone triste (wah, wah, wah, waaah): quatro notas descendo com surdina."""
    out = []
    notes = [("D4", 0.42), ("C#4", 0.42), ("C4", 0.42), ("B3", 1.6)]
    at = 0.0
    for index, (name, length) in enumerate(notes):
        last = index == len(notes) - 1
        f0 = note_hz(name)
        # "Wa": a surdina abre (brilho sobe) e fecha em cada nota.
        def bright(t, length=length):
            return 0.25 + 0.6 * math.sin(math.pi * min(1.0, t / (0.6 * length))) ** 0.7
        vib = (lambda t: (5.5, 0.018 * min(1.0, t / 0.5))) if last else (5.0, 0.004)
        freq = (lambda t, f0=f0: f0 * (1.0 - 0.03 * max(0.0, t - 1.1))) if last else f0
        note = tone(length + 0.05, freq, saw_harmonics(18, 0.9), vibrato=vib, brightness=bright)
        note = envelope(note, 0.03, 0.12 if last else 0.06)
        mix_into(out, note, at)
        at += length
    return reverb(out, wet=0.18, room=0.7, tail=0.6)


def fall_whistle():
    """Apito de êmbolo descendo (a queda de desenho animado) e um "puf" no fim."""
    length = 1.5
    whistle = tone(length, lambda t: 1700.0 * (300.0 / 1700.0) ** (t / length), [(1, 1.0), (2, 0.12)],
                   vibrato=(6.0, 0.012), amp=lambda t: min(1.0, t / 0.03) * (1.0 - 0.3 * t / length))
    breath = envelope(bandpass(noise(length, 9), 900, 4000), 0.03, 0.1)
    mix_into(whistle, breath, 0.0, 0.06)
    whistle = envelope(whistle, 0.02, 0.08)
    puff = envelope(lowpass(noise(0.35, 11), 700), 0.005, 0.3, decay=8.0)
    mix_into(whistle, puff, length + 0.03, 1.2)
    return reverb(whistle, wet=0.15, room=0.65, tail=0.4)


def airhorn():
    """Buzina de estádio: dois toques curtos e um longo, rasgados."""
    out = []
    at = 0.0
    for length in (0.17, 0.17, 0.85):
        blast = [0.0] * frames(length)
        for detune in (0.0, 1.8, -2.4):
            layer = tone(length, lambda t, d=detune: (452.0 + d) * (1.0 + 0.04 * (1.0 - math.exp(-t * 30.0))),
                         saw_harmonics(28, 1.0))
            mix_into(blast, layer, 0.0, 0.4)
        blast = envelope(soft_clip(blast, 3.2), 0.006, 0.05)
        mix_into(out, blast, at)
        at += length + 0.07
    return reverb(out, wet=0.2, room=0.75, tail=0.6)


def record_scratch():
    """Arranhão de disco ("yep, that's me"): a música vai e volta e para."""
    source = [0.0] * frames(1.2)
    for name in ("C4", "E4", "G4", "C3"):
        mix_into(source, tone(1.2, note_hz(name), saw_harmonics(12, 1.1), amp=0.3))
    beat = envelope(lowpass(noise(0.08, 13), 3000), 0.001, 0.06)
    for k in range(4):
        mix_into(source, beat, k * 0.25, 0.8)
    source = lowpass(source, 3500)
    # Velocidade da agulha: frente rápida, trás, frente, e freia até parar.
    speed_points = [(0.0, 1.0), (0.05, 3.2), (0.12, -2.8), (0.19, 3.0), (0.26, -1.5), (0.31, 1.2), (0.65, 0.0)]

    def speed(t):
        for (t0, v0), (t1, v1) in zip(speed_points, speed_points[1:]):
            if t <= t1:
                return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
        return 0.0

    out = []
    position = 0.3 * RATE
    rng = random.Random(17)
    for i in range(frames(0.7)):
        t = i / RATE
        v = speed(t)
        position += v
        index = int(position) % (len(source) - 1)
        frac = position - int(position)
        sample = source[index] * (1 - frac) + source[index + 1] * frac
        # Atrito da agulha: chiado que acompanha a velocidade.
        sample += rng.uniform(-1, 1) * 0.15 * min(1.0, abs(v))
        out.append(sample)
    out = bandpass(out, 120, 6000)
    return envelope(out, 0.002, 0.03)


def rimshot():
    """"Ba dum tss": dois tambores e o prato."""
    out = []
    for at, start, end in ((0.0, 230.0, 150.0), (0.16, 165.0, 105.0)):
        drum = tone(0.35, lambda t, s=start, e=end: e + (s - e) * math.exp(-t * 25.0), [(1, 1.0), (1.5, 0.3)],
                    amp=lambda t: math.exp(-t * 10.0))
        mix_into(drum, envelope(lowpass(noise(0.02, 21), 3000), 0.001, 0.015), 0.0, 0.4)
        mix_into(out, drum, at)
    cymbal = [0.0] * frames(1.6)
    # Prato metálico: ondas quadradas em frequências "desencontradas" + chiado, só os agudos.
    for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0):
        mix_into(cymbal, tone(1.6, f, square_harmonics(8)), 0.0, 0.15)
    mix_into(cymbal, noise(1.6, 23), 0.0, 0.6)
    cymbal = envelope(highpass(highpass(cymbal, 5000), 5000), 0.001, 0.2, decay=2.6)
    mix_into(out, cymbal, 0.38, 1.4)
    return out


def dun_dun():
    """"Dun dun DUNNN": três acordes de metais com tímpano; o último longo e mais grave."""
    out = []
    hits = [(0.0, ("D3", "F3", "A3", "D4"), 0.26), (0.32, ("D3", "F3", "A3", "D4"), 0.26),
            (0.64, ("C#2", "G2", "C#3", "G3"), 2.2)]
    for at, chord, length in hits:
        last = length > 1.0
        stack = [0.0] * frames(length)
        for name in chord:
            voice = tone(length, note_hz(name), saw_harmonics(16, 1.25),
                         vibrato=(6.5, 0.006) if last else None,
                         amp=(lambda t: 1.0 + 0.25 * math.sin(TAU * 7.0 * t)) if last else None)
            mix_into(stack, voice, 0.0, 0.3)
        stack = envelope(stack, 0.015, 0.5 if last else 0.08)
        timpani = tone(1.0, lambda t: 58.0 + 18.0 * math.exp(-t * 20.0), [(1, 1.0), (1.5, 0.3)],
                       amp=lambda t: math.exp(-t * 4.0))
        mix_into(stack, timpani, 0.0, 0.8)
        mix_into(out, stack, at)
    return reverb(out, wet=0.3, room=0.84, tail=1.2)


def kazoo_fanfare():
    """Fanfarra de vitória no kazoo (zumbido anasalado)."""
    out = []
    melody = [("G4", 0.12), ("C5", 0.12), ("E5", 0.12), ("G5", 0.32), ("E5", 0.12), ("G5", 0.95)]
    at = 0.0
    # Formantes do kazoo: pesos dos harmônicos puxados para ~1,1 kHz e ~2,6 kHz.
    for index, (name, length) in enumerate(melody):
        f0 = note_hz(name)
        harmonics = []
        for h in range(1, 24):
            f = h * f0
            weight = (1.0 / h ** 0.6) * (0.25 + math.exp(-((f - 1100.0) / 500.0) ** 2)
                                          + 0.6 * math.exp(-((f - 2600.0) / 700.0) ** 2))
            harmonics.append((h, weight))
        last = index == len(melody) - 1
        note = tone(length + 0.03, f0, harmonics, vibrato=(6.0, 0.02 if last else 0.008))
        buzz = envelope(highpass(noise(length + 0.03, 31 + index), 1500), 0.01, 0.03)
        mix_into(note, buzz, 0.0, 0.08)
        mix_into(out, envelope(soft_clip(note, 1.5), 0.012, 0.05 if not last else 0.15), at)
        at += length
    return reverb(out, wet=0.15, room=0.7, tail=0.5)


def error_beep():
    """Bipe de "deu erro" (duas notas descendo)."""
    out = []
    mix_into(out, envelope(tone(0.1, 880.0, square_harmonics(6)), 0.003, 0.01))
    mix_into(out, envelope(tone(0.18, 587.3, square_harmonics(6)), 0.003, 0.03), 0.14)
    return lowpass(out, 5000)


def modem():
    """Modem discado: tom de linha, disco, e a "conversa" de apitos e chiado."""
    out = []
    at = 0.0
    mix_into(out, envelope(tone(0.35, lambda t: 1.0, [(350, 0.5), (440, 0.5)]), 0.01, 0.01), at)
    at += 0.42
    rng = random.Random(41)
    for _ in range(7):
        low = rng.choice((697.0, 770.0, 852.0, 941.0))
        high = rng.choice((1209.0, 1336.0, 1477.0))
        mix_into(out, envelope(tone(0.07, lambda t: 1.0, [(low, 0.5), (high, 0.5)]), 0.003, 0.005), at)
        at += 0.11
    at += 0.15
    mix_into(out, envelope(tone(0.45, 2100.0), 0.01, 0.02), at, 0.6)
    at += 0.5
    # Apitos da negociação (frequências trocando rápido).
    handshake = []
    for k in range(10):
        f = rng.choice((1070.0, 1270.0, 2025.0, 2225.0, 1650.0, 1850.0))
        mix_into(handshake, envelope(tone(0.05, f, [(1, 1.0), (3, 0.2)]), 0.002, 0.004), k * 0.045)
    mix_into(out, handshake, at, 0.5)
    at += 0.48
    static = bandpass(noise(0.75, 43), 600, 3500)
    static = [x * (0.6 + 0.4 * math.sin(TAU * 13.0 * i / RATE)) for i, x in enumerate(static)]
    mix_into(out, envelope(static, 0.02, 0.1), at, 0.9)
    mix_into(out, envelope(tone(0.75, lambda t: 1800.0 + 300.0 * math.sin(TAU * 3.0 * t)), 0.02, 0.1), at, 0.2)
    return out


def gong():
    """Gongo: parciais desencontrados que "florescem" depois da batida e somem devagar."""
    length = 5.0
    base = 98.0
    out = [0.0] * frames(length)
    rng = random.Random(51)
    for index, ratio in enumerate((1.0, 1.46, 1.93, 2.39, 2.82, 3.29, 3.73, 4.2, 5.1, 6.3, 7.4)):
        f = base * ratio * (1.0 + rng.uniform(-0.004, 0.004))
        bloom = 0.02 if index < 2 else 0.12 + 0.05 * index
        decay = 0.8 + 0.25 * index
        weight = 1.0 / (1.0 + 0.35 * index)
        partial = tone(length, lambda t, f=f: f * (1.0 + 0.002 * math.sin(TAU * 0.7 * t)),
                       amp=lambda t, b=bloom, d=decay: min(1.0, t / b) * math.exp(-d * t))
        mix_into(out, partial, 0.0, weight)
    thump = tone(0.3, lambda t: 50.0 + 30.0 * math.exp(-t * 30.0), amp=lambda t: math.exp(-t * 14.0))
    mix_into(out, thump, 0.0, 0.8)
    return reverb(envelope(out, 0.002, 1.2), wet=0.35, room=0.88, tail=1.5)


def piano_note(name, length, velocity=1.0):
    f0 = note_hz(name)
    out = [0.0] * frames(length)
    for h in range(1, 9):
        f = h * f0 * math.sqrt(1.0 + 0.0004 * h * h)
        if f > RATE * 0.45:
            break
        partial = tone(length, f, amp=lambda t, h=h: math.exp(-(1.2 + 0.7 * h) * t))
        mix_into(out, partial, 0.0, velocity / h ** 1.4)
    hammer = envelope(lowpass(noise(0.015, int(f0)), 2500), 0.001, 0.01)
    mix_into(out, hammer, 0.0, 0.15 * velocity)
    return envelope(out, 0.004, 0.15)


def funeral_march():
    """Marcha fúnebre de Chopin (1839, domínio público): o começo tão conhecido, no piano."""
    beat = 0.6
    melody = [("Bb3", 1.0), ("Bb3", 0.75), ("Bb3", 0.25), ("Bb3", 1.0), ("Db4", 0.75), ("C4", 0.25),
              ("C4", 0.75), ("Bb3", 0.25), ("Bb3", 0.75), ("A3", 0.25), ("Bb3", 1.5)]
    chords = [("Bb1", "F2", "Db3"), ("Gb1", "Db2", "Bb2")]
    out = []
    at = 0.0
    for name, beats in melody:
        mix_into(out, piano_note(name, beats * beat + 1.0, 0.9), at)
        at += beats * beat
    total_beats = int(sum(b for _, b in melody))
    for k in range(total_beats):
        for name in chords[(k // 2) % 2]:
            mix_into(out, piano_note(name, 1.6, 0.45), k * beat)
    return reverb(out, wet=0.25, room=0.8, tail=1.0)


def metal_pipe():
    """Cano de metal caindo no chão: batida metálica que fica ressoando, e dois quiques."""
    out = []
    # Modos de uma barra solta nas pontas (1 : 2,756 : 5,404 : 8,933 : 13,34), em pares quase
    # iguais (o tubo "bate" e tremula).
    modes = [(1.0, 1.0, 1.1), (2.756, 0.7, 1.7), (5.404, 0.5, 2.6), (8.933, 0.35, 3.6), (13.34, 0.22, 4.8)]
    for at, gain in ((0.0, 1.0), (0.21, 0.45), (0.34, 0.22)):
        hit = [0.0] * frames(2.6)
        for ratio, weight, decay in modes:
            for detune in (1.0, 1.0035):
                partial = tone(2.6, 540.0 * ratio * detune, amp=lambda t, d=decay: math.exp(-d * t))
                mix_into(hit, partial, 0.0, weight * 0.5)
        mix_into(hit, envelope(highpass(noise(0.02, 61), 3000), 0.0005, 0.015), 0.0, 0.6)
        mix_into(out, hit, at, gain)
    return reverb(envelope(out, 0.0005, 0.6), wet=0.2, room=0.75, tail=0.8)


def boing():
    """"Boing" de mola."""
    out = tone(0.6, lambda t: 140.0 * (1.0 + 2.2 * (1.0 - math.exp(-t * 7.0))), [(1, 1.0), (2, 0.4), (3, 0.2)],
               vibrato=lambda t: (16.0, 0.12 * math.exp(-t * 4.0)), amp=lambda t: math.exp(-t * 4.5))
    return envelope(out, 0.004, 0.05)


## [nome, função, pico em dB]. Os picos equilibram o volume que se ouve (medido em LUFS: a buzina e
## o kazoo soavam o dobro do bonk e do gongo com o mesmo pico).
SOUNDS = [
    ("boom", boom, -1.0),
    ("bonk", bonk, -1.0),
    ("sad_trombone", sad_trombone, -7.0),
    ("fall_whistle", fall_whistle, -6.0),
    ("airhorn", airhorn, -8.0),
    ("record_scratch", record_scratch, -4.0),
    ("rimshot", rimshot, -1.0),
    ("dun_dun", dun_dun, -3.0),
    ("kazoo_fanfare", kazoo_fanfare, -8.0),
    ("error", error_beep, -6.0),
    ("modem", modem, -6.0),
    ("gong", gong, -1.0),
    ("funeral_march", funeral_march, -3.0),
    ("boing", boing, -4.0),
    ("metal_pipe", metal_pipe, -1.0),
]

## Trechos das gravações CC0: [nome, arquivo, começo (s), fim (s), pico em dB].
RECORDED = [
    ("ka_ching", "209578__zott820__cash-register-purchase.wav", 0.0, 1.62, -3.0),
    ("crowd_ooh", "264499__noah0189__crowd-ooohs-and-ahhhs-in-excitement.wav", 0.0, 1.95, -3.0),
    ("laugh_1", "383207__kinoton__sitcom-laughter-9x-small-audience.wav", 7.45, 10.35, -3.0),
    ("laugh_2", "383207__kinoton__sitcom-laughter-9x-small-audience.wav", 15.05, 18.15, -3.0),
    ("crickets", "129678__freethinkeranon__crickets.mp3", 2.0, 5.2, -8.0),
]


def cut(source, start, end, fade=0.08):
    """Trecho [start, end] de uma gravação, com entrada e saída suaves."""
    samples = to_mono_16(os.path.join(FREESOUND, source))[frames(start):frames(end)]
    return envelope(samples, min(fade, 0.03), fade)


def main():
    board = []
    print("Sons de meme (sintetizados):")
    for name, make, peak in SOUNDS:
        samples = normalize(trim_tail(make()), peak)
        write(os.path.join(OUT, "meme_%s.wav" % name), samples)
        print("    na prévia em %d:%04.1f" % divmod(len(board) / RATE, 60))
        board.extend(samples + silence(0.8))
    print("Trechos das gravações CC0 (Freesound):")
    for name, source, start, end, peak in RECORDED:
        samples = normalize(cut(source, start, end), peak)
        write(os.path.join(OUT, "meme_%s.wav" % name), samples)
        print("    na prévia em %d:%04.1f" % divmod(len(board) / RATE, 60))
        board.extend(samples + silence(0.8))
    if len(sys.argv) > 1:
        write(os.path.join(sys.argv[1], "meme_board.wav"), board)


if __name__ == "__main__":
    main()
