"""Extract the user's NES cartridge data; the 6502 is used only during import."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib
from py65.devices.mpu6502 import MPU

parser = argparse.ArgumentParser()
parser.add_argument("rom", type=Path)
parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "data")
args = parser.parse_args()
rom = args.rom.read_bytes()
if rom[:8] != bytes([78, 69, 83, 26, 2, 4, 49, 0]):
    raise SystemExit("Expected Puzznic USA, iNES mapper 3, 32 KiB PRG / 32 KiB CHR.")
prg = rom[16:32784]
expected = "5759d98edbb49cd9b2072dc74600cd73999c82e5f2d617e71d091e5fa8beea96"
if hashlib.sha256(rom).hexdigest() != expected:
    raise SystemExit("This decoder is verified for Puzznic (USA); unexpected ROM revision.")

def call(cpu, address):
    cpu.pc = address
    cpu.sp = 0xFF
    cpu.stPushWord(0x7FFF)
    for _ in range(100000):
        if cpu.pc == 0x8000:
            return
        cpu.step()
    raise ValueError("Decoder did not return")

def bcd(value):
    return (value >> 4) * 10 + (value & 15)

levels = []
for mode, count in [(0, 160), (1, 80)]:
    for index in range(count):
        cpu = MPU()
        cpu.memory[0x8000:] = prg
        cpu.memory[0x509] = index
        cpu.memory[0x6E8] = mode
        call(cpu, 0x9A79)
        cpu.memory[0x21] = cpu.x
        cpu.memory[0x22] = cpu.a
        record = cpu.memory[0x32] + (cpu.memory[0x33] << 8) + ((index * 4) & 255)
        minutes, seconds = cpu.memory[record + 2:record + 4]
        call(cpu, 0xA0CF if mode == 0 else 0x9AC4)
        grid = cpu.memory[0x559:0x5D1]
        assert len(grid) == 120 and all(0 <= c <= 15 for c in grid)
        assert sum(c >= 8 for c in grid) >= 2
        call(cpu, 0xE635)
        password = "".join(chr(c + 47) for c in cpu.memory[0x370:0x374])
        call(cpu, 0xDA3C)
        world_offset = cpu.memory[0x6D9] * 2
        stage_pair = prg[0xDC47 - 0x8000 + world_offset:0xDC49 - 0x8000 + world_offset]
        time_pair = prg[0xDC19 - 0x8000 + world_offset:0xDC1B - 0x8000 + world_offset]
        stage_bonus = (bcd(stage_pair[0]) * 100 + bcd(stage_pair[1])) * 10
        time_bonus = (bcd(time_pair[0]) * 100 + bcd(time_pair[1])) * 10
        levels.append({"index": index, "mode": mode, "name": f"{index // 10 + 1}-{index % 10 + 1}",
                       "time": bcd(minutes) * 60 + bcd(seconds),
                       "password": password,
                       "stage_bonus": stage_bonus, "time_bonus_per_second": time_bonus,
                       "grid": [grid[y * 10:y * 10 + 10] for y in range(12)]})

args.output.mkdir(parents=True, exist_ok=True)
digest = hashlib.sha256(rom).hexdigest()
(args.output / "levels.json").write_text(json.dumps({"source": "Puzznic (USA), NES", "rom_sha256": digest, "levels": levels}, indent=2) + "\n")

# The original 16x16 symbols consist of four 8x8 CHR tiles.
palette = [(0, 0, 0, 0), (0, 108, 0, 255), (0, 188, 0, 255), (252, 252, 252, 255),
           (0, 0, 0, 0), (0, 0, 0, 255), (124, 124, 124, 255), (252, 252, 252, 255),
           (0, 0, 0, 0), (168, 0, 32, 255), (248, 120, 88, 255), (252, 252, 252, 255),
           (0, 0, 0, 0), (0, 108, 0, 255), (0, 188, 0, 255), (252, 252, 252, 255)]
# Palette 0 is blue; palette 3 is green, matching the cartridge.
palette[:4] = [(0, 0, 0, 0), (0, 88, 248, 255), (60, 188, 252, 255), (252, 252, 252, 255)]
width, height = 128, 16
rgba = bytearray(width * height * 4)
for kind in range(8):
    table = 0x9B30 - 0x8000 + (kind + 8) * 2
    tile, pal = prg[table:table + 2]
    for y in range(16):
        for x in range(16):
            t = tile + (x // 8) * 2 + y // 8
            offset = 32784 + 0x1000 + t * 16
            bit = 7 - x % 8
            color = ((rom[offset + y % 8] >> bit) & 1) | (((rom[offset + y % 8 + 8] >> bit) & 1) << 1)
            pos = (y * width + kind * 16 + x) * 4
            rgba[pos:pos + 4] = bytes(palette[pal * 4 + color])

def chunk(tag, content):
    return struct.pack(">I", len(content)) + tag + content + struct.pack(">I", zlib.crc32(tag + content) & 0xFFFFFFFF)

scanlines = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b"")
(args.output / "nes_symbols.png").write_bytes(png)
print(f"Extracted 160 Puzznic + 80 Gravnic levels and NES symbols. SHA-256: {digest}")
