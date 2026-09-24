#!/usr/bin/env python3
"""Monta o vídeo de prévia da App Store (App Preview) gravado pelo tools/app_preview.gd.

    python3 tools/make_app_preview.py <pasta> <saida.mp4>

Lê <pasta>/segments.json, os quadros <pasta>/frames/f00000.png... e o som do jogo em
<pasta>/game.avi (Movie Maker, gravado SEM a música). Corta o som nos mesmos trechos do vídeo
(com um fade curtinho em cada corte, senão estala), põe a música da partida por cima, inteira
(sem pulos nos cortes), e grava o que a Apple pede para App Preview: H.264 High, 30 quadros por
segundo, yuv420p, ~10 Mbps, e AAC estéreo 256 kbps 48 kHz. O fim escurece e a música some.
Precisa do ffmpeg (Homebrew: /opt/homebrew/bin/ffmpeg).
"""

import json
import os
import shutil
import subprocess
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(PROJECT, "assets/audio/music/maple_leaf_rag_piano.ogg")
## Música um pouco mais alta que no jogo (lá: -14 dB no player e 60% no canal Music).
MUSIC_DB = -12.0
## Fades dos cortes do som e do fim do vídeo (segundos).
CUT_FADE_IN = 0.02
CUT_FADE_OUT = 0.03
END_FADE_VIDEO = 0.6
END_FADE_MUSIC = 1.2
## O quadro salvo no contador m do app_preview.gd é o desenhado DOIS passos antes (o contador
## sobe antes do quadro atual, e get_image() devolve o anterior); o som daquele desenho é o do
## pedaço m - 2 do game.avi.
AUDIO_LAG_FRAMES = 2


def ffmpeg() -> str:
    for path in (shutil.which("ffmpeg"), "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"):
        if path and os.path.exists(path):
            return path
    sys.exit("ffmpeg não encontrado (brew install ffmpeg)")


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    folder, output = sys.argv[1], sys.argv[2]
    info = json.load(open(os.path.join(folder, "segments.json")))
    fps = float(info["fps"])
    segments = info["segments"]
    duration = info["frames"] / fps

    graph = []
    # Som do jogo: um pedaço por trecho gravado, com fade nas pontas, emendados.
    graph.append("[1:a]asplit=%d%s" % (len(segments), "".join("[g%d]" % i for i in range(len(segments)))))
    for i, (start, end) in enumerate(segments):
        length = (end - start) / fps
        graph.append(
            "[g%d]atrim=start=%.4f:end=%.4f,asetpts=PTS-STARTPTS,"
            "afade=t=in:d=%.3f,afade=t=out:st=%.4f:d=%.3f[s%d]"
            % (i, (start - AUDIO_LAG_FRAMES) / fps, (end - AUDIO_LAG_FRAMES) / fps, CUT_FADE_IN,
               length - CUT_FADE_OUT, CUT_FADE_OUT, i))
    graph.append("%sconcat=n=%d:v=0:a=1,aformat=sample_rates=48000:channel_layouts=stereo[sfx]"
                 % ("".join("[s%d]" % i for i in range(len(segments))), len(segments)))
    # Música contínua por cima.
    graph.append(
        "[2:a]atrim=0:%.4f,asetpts=PTS-STARTPTS,volume=%.1fdB,afade=t=out:st=%.4f:d=%.2f,"
        "aformat=sample_rates=48000:channel_layouts=stereo[music]"
        % (duration, MUSIC_DB, duration - END_FADE_MUSIC, END_FADE_MUSIC))
    graph.append("[sfx][music]amix=inputs=2:normalize=0:duration=first,"
                 "loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[audio]")
    # Vídeo: escurece no fim.
    graph.append("[0:v]format=yuv420p,fade=t=out:st=%.4f:d=%.2f[video]"
                 % (duration - END_FADE_VIDEO, END_FADE_VIDEO))

    command = [
        ffmpeg(), "-y", "-hide_banner", "-loglevel", "error",
        "-framerate", "%g" % fps, "-i", os.path.join(folder, "frames/f%05d.png"),
        "-i", os.path.join(folder, "game.avi"),
        "-stream_loop", "-1", "-i", MUSIC,
        "-filter_complex", ";".join(graph),
        "-map", "[video]", "-map", "[audio]",
        "-c:v", "libx264", "-profile:v", "high", "-level:v", "4.0", "-preset", "slow",
        "-b:v", "10M", "-maxrate", "12M", "-bufsize", "16M", "-pix_fmt", "yuv420p", "-r", "%g" % fps,
        "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2",
        "-t", "%.4f" % duration, "-movflags", "+faststart", output,
    ]
    subprocess.run(command, check=True)
    print("OK %s (%.1f s)" % (output, duration))


if __name__ == "__main__":
    main()
