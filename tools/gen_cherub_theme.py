#!/usr/bin/env python3
"""The cherub's theme for the new-climb cutscene (NewGameIntro): somber, then hopeful.

An original composition, written here as MIDI note by note (no third-party
melody). D minor at 66 BPM, eight bars (~29 s), sized to the cutscene:
  bars 1-2  cello drone, strings and a lone harp while she is carried down
  bar 3     a soft timpani swell lands on "Arise, fallen one!"
  bars 3-6  a French horn climbs over the choir (the command, the promise)
  bars 7-8  the minor turns to D major: the Golden Hall, far above

Usage (from the project root):
  python3 tools/gen_cherub_theme.py                 # writes the .mid only
  python3 tools/gen_cherub_theme.py --sf2 <path>    # also renders the .ogg

Rendering needs fluidsynth, ffmpeg and oggenc on PATH, and the "GeneralUser GS"
v1.47 SoundFont (https://schristiancollins.com/generaluser.php), the same one
the realm soundtracks use. Output: assets/music/themes/cherub.mid / cherub.ogg,
normalized to about -18 LUFS like the realm tracks.
"""
import argparse
import os
import shutil
import struct
import subprocess
import tempfile

OUT_DIR = os.path.join("assets", "music", "themes")
NAME = "cherub"
BPM = 66
TPB = 480  # ticks per beat
BAR = 4 * TPB

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
        "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def n(name: str) -> int:
    """'D4' -> 62 (C4 = 60)."""
    pitch, octave = (name[:2], name[2:]) if name[1:2] in "#b" else (name[:1], name[1:])
    return 12 * (int(octave) + 1) + NOTE[pitch]


# Channel, GM program, volume, reverb send.
STRINGS, CELLO, CHOIR, HARP, HORN, CELESTA, TIMPANI = range(7)
INSTRUMENTS = {
    STRINGS: (48, 92, 110),   # String Ensemble 1
    CELLO: (42, 96, 100),     # Cello
    CHOIR: (52, 80, 120),     # Choir Aahs
    HARP: (46, 84, 110),      # Orchestral Harp
    HORN: (60, 100, 100),     # French Horn
    CELESTA: (8, 70, 120),    # Celesta
    TIMPANI: (47, 90, 90),    # Timpani
}

# One chord per half bar: (bass, upper voices).
CHORDS = [
    ("D2", ["D3", "F3", "A3", "D4"]), ("D2", ["D3", "F3", "A3", "D4"]),      # Dm
    ("Bb1", ["D3", "F3", "Bb3", "D4"]), ("Bb1", ["D3", "F3", "Bb3", "D4"]),  # Bb
    ("G1", ["G3", "Bb3", "D4", "G4"]), ("G1", ["G3", "Bb3", "D4", "G4"]),    # Gm  (Arise)
    ("A1", ["A3", "D4", "E4", "A4"]), ("A1", ["A3", "C#4", "E4", "A4"]),     # Asus4 -> A
    ("Bb1", ["Bb3", "D4", "F4", "Bb4"]), ("Bb1", ["Bb3", "D4", "F4", "Bb4"]),  # Bb
    ("A1", ["F3", "A3", "C4", "F4"]), ("C2", ["G3", "C4", "E4", "G4"]),      # F/A, C
    ("G1", ["Bb3", "D4", "F4", "G4"]), ("A1", ["A3", "C#4", "E4", "A4"]),    # Gm7, A
    ("D2", ["D3", "F#3", "A3", "D4"]), ("D2", ["D3", "F#3", "A3", "D4"]),    # D major
]

# Horn: (start beat, length in beats, note, velocity). Beat 0 = bar 1.
MELODY = [
    (6, 2, "A3", 58),
    (8, 2, "D4", 66), (10, 1, "F4", 70), (11, 1, "E4", 66),
    (12, 2, "E4", 70), (14, 2, "C#4", 64),
    (16, 1, "D4", 72), (17, 1, "F4", 76), (18, 2, "Bb4", 84),
    (20, 2, "A4", 86), (22, 1, "G4", 78), (23, 1, "E4", 74),
    (24, 2, "F4", 80), (26, 2, "E4", 76),
    (28, 4, "F#4", 84),
]


class Track:
    def __init__(self) -> None:
        self.events: list[tuple[int, int, bytes]] = []  # (tick, order, data)

    def add(self, tick: int, data: bytes, order: int = 1) -> None:
        self.events.append((tick, order, data))

    def note(self, ch: int, start: int, length: int, pitch: int, vel: int) -> None:
        self.add(start, bytes([0x90 | ch, pitch, max(1, min(127, vel))]), 1)
        self.add(start + length, bytes([0x80 | ch, pitch, 0]), 0)  # offs before ons

    def cc(self, ch: int, tick: int, num: int, value: int) -> None:
        self.add(tick, bytes([0xB0 | ch, num, value]), 0)

    def encode(self) -> bytes:
        out = bytearray()
        last = 0
        for tick, _, data in sorted(self.events, key=lambda e: (e[0], e[1])):
            out += vlq(tick - last) + data
            last = tick
        out += vlq(0) + b"\xff\x2f\x00"
        return b"MTrk" + struct.pack(">I", len(out)) + bytes(out)


def vlq(value: int) -> bytes:
    out = [value & 0x7F]
    value >>= 7
    while value:
        out.append(0x80 | (value & 0x7F))
        value >>= 7
    return bytes(reversed(out))


def compose() -> bytes:
    t = Track()
    tempo = 60_000_000 // BPM
    t.add(0, b"\xff\x51\x03" + tempo.to_bytes(3, "big"), 0)
    t.add(0, b"\xff\x58\x04\x04\x02\x18\x08", 0)
    for ch, (program, volume, reverb) in INSTRUMENTS.items():
        t.add(0, bytes([0xC0 | ch, program]), 0)
        t.cc(ch, 0, 7, volume)
        t.cc(ch, 0, 91, reverb)
        t.cc(ch, 0, 93, 20)

    half = BAR // 2
    for i, (bass, upper) in enumerate(CHORDS):
        start = i * half
        bar = i // 2
        hopeful = bar >= 4
        # Cello: one long note per chord change (held through repeats).
        if i == 0 or CHORDS[i - 1][0] != bass:
            length = half
            j = i + 1
            while j < len(CHORDS) and CHORDS[j][0] == bass:
                length += half
                j += 1
            t.note(CELLO, start, length - 10, n(bass) + 12, 62 + bar * 3)
        # Strings: the voicing, swelling as the piece opens up.
        if i == 0 or CHORDS[i - 1][1] != upper:
            length = half
            j = i + 1
            while j < len(CHORDS) and CHORDS[j][1] == upper:
                length += half
                j += 1
            for p in upper:
                t.note(STRINGS, start, length - 10, n(p), 44 + bar * 5)
            # Choir from bar 2: the top three voices, an octave up once hopeful.
            if bar >= 1:
                for p in upper[1:]:
                    t.note(CHOIR, start, length - 10, n(p) + (12 if hopeful and p == upper[-1] else 0), 34 + bar * 5)
        # Harp: eighth-note arpeggio up the chord, sparse at first.
        pattern = [0, 1, 2, 3, 2, 3, 1, 2]
        for k in range(4):
            if bar == 0 and k % 2:
                continue
            p = n(upper[pattern[(i % 2) * 4 + k]]) + 12
            t.note(HARP, start + k * (TPB // 2), TPB, p, 40 + (10 if hopeful else 0) + (8 if k == 0 else 0))
        # Celesta: high chord tones once the hope arrives.
        if hopeful:
            t.note(CELESTA, start, TPB, n(upper[-1]) + 12, 46)
            t.note(CELESTA, start + TPB, TPB, n(upper[1]) + 24, 38)

    # Timpani: a soft roll in bar 2 that lands on bar 3 ("Arise").
    roll_start = BAR + 2 * TPB
    steps = 16
    for k in range(steps):
        t.note(TIMPANI, roll_start + k * (2 * TPB // steps), TPB // 8, n("D2"), 30 + k * 4)
    t.note(TIMPANI, 2 * BAR, TPB * 2, n("D2"), 100)
    # ...and one last quiet stroke under the D major.
    t.note(TIMPANI, 7 * BAR, TPB * 2, n("D2"), 60)

    for beat, length, pitch, vel in MELODY:
        t.note(HORN, beat * TPB, length * TPB - 30, n(pitch), vel)

    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, TPB)
    return header + t.encode()


def render(mid_path: str, sf2: str, ogg_path: str) -> None:
    for tool in ("fluidsynth", "ffmpeg", "oggenc"):
        if shutil.which(tool) is None:
            raise SystemExit(f"{tool} not found on PATH")
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "raw.wav")
        cut = os.path.join(tmp, "cut.wav")
        norm = os.path.join(tmp, "norm.wav")
        subprocess.run(["fluidsynth", "-ni", "-q", "-g", "0.7", "-r", "44100", "-F", raw, sf2, mid_path], check=True)
        # Trim to the eight bars plus the reverb tail of the last chord, fade it out.
        length = 8 * 4 * 60 / BPM + 3.5
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", raw,
                        "-af", f"atrim=0:{length:.2f},afade=t=out:st={length - 2.5:.2f}:d=2.5", cut], check=True)
        # Measure integrated loudness, then set the gain to land on -18 LUFS.
        report = subprocess.run(["ffmpeg", "-hide_banner", "-i", cut, "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                                capture_output=True, text=True).stderr
        lufs = float(report.rsplit("I:", 1)[1].split("LUFS")[0])
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", cut,
                        "-af", f"volume={-18.0 - lufs:.2f}dB,alimiter=limit=0.89", norm], check=True)
        subprocess.run(["oggenc", "-Q", "-q", "5", "-o", ogg_path, norm], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sf2", help="GeneralUser GS SoundFont, to also render the .ogg")
    args = parser.parse_args()
    os.makedirs(OUT_DIR, exist_ok=True)
    mid_path = os.path.join(OUT_DIR, NAME + ".mid")
    with open(mid_path, "wb") as f:
        f.write(compose())
    print("wrote", mid_path)
    if args.sf2:
        ogg_path = os.path.join(OUT_DIR, NAME + ".ogg")
        render(mid_path, args.sf2, ogg_path)
        print("wrote", ogg_path)


if __name__ == "__main__":
    main()
