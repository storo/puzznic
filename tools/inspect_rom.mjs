// Development reference capture only. Godot does not emulate the cartridge.
import fs from 'node:fs';
import {NES, Controller} from 'jsnes';
const rom = fs.readFileSync(process.argv[2]);
let pixels;
let recording = false;
const samples = [];
const captureMusic = process.argv.includes('--music');
const nes = new NES({
  onFrame: frame => pixels = frame.slice(),
  emulateSound: captureMusic,
  sampleRate: 44100,
  onAudioSample: (left, right) => { if (recording) samples.push((left + right) / 2); },
});
nes.loadROM(rom);
function frames(count) { for (let i = 0; i < count; i++) nes.frame(); }
function press(button) { nes.buttonDown(1, button); frames(12); nes.buttonUp(1, button); frames(120); }
frames(600);
press(Controller.BUTTON_START);
press(Controller.BUTTON_START);
press(Controller.BUTTON_START);
frames(180);
if (process.argv.includes('--solve-first')) {
  nes.buttonDown(1, Controller.BUTTON_A);
  nes.buttonDown(1, Controller.BUTTON_LEFT);
  frames(120);
  nes.buttonUp(1, Controller.BUTTON_LEFT);
  nes.buttonUp(1, Controller.BUTTON_A);
  frames(60);
  console.log('NES score BCD', nes.cpu.mem.slice(0x503, 0x506));
}
if (captureMusic) {
  recording = true;
  for (let i = 0; i < 1800; i++) {
    nes.cpu.mem[0x50d] = 9; // Keep the normal music, before the time warning.
    nes.frame();
  }
  const wav = Buffer.alloc(44 + samples.length * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(44100, 24); wav.writeUInt32LE(88200, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36);
  wav.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((sample, i) => wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), 44 + i * 2));
  const path = new URL('../data/nes_music.wav', import.meta.url);
  fs.writeFileSync(path, wav);
  console.log(`Captured original NES music: ${samples.length / 44100} seconds.`);
}
const output = '/tmp/puzznic-nes-reference';
const header = Buffer.from('P6\n256 240\n255\n');
const rgb = Buffer.alloc(256*240*3);
pixels.forEach((p,i)=> {rgb[i*3]=p&255;rgb[i*3+1]=(p>>8)&255;rgb[i*3+2]=(p>>16)&255;});
fs.writeFileSync(output+'.ppm',Buffer.concat([header,rgb]));
fs.writeFileSync(output+'-ram.bin',Buffer.from(nes.cpu.mem.slice(0,2048)));
fs.writeFileSync(output+'-ppu.bin',Buffer.from(nes.ppu.vramMem));
console.log('Captured',output);
