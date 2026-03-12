const test = require('node:test');
const assert = require('node:assert/strict');

const {
  STATE_CONFIGS,
  APP_ICONSET_SPECS,
  WAVE_CYCLES,
  generateWavePath,
  generateLogoSvg,
  getExportFilename
} = require('./logo_generator.js');

test('busy and idle states are defined with busy carrying clearly stronger motion', () => {
  assert.ok(STATE_CONFIGS.busy);
  assert.ok(STATE_CONFIGS.idle);
  assert.ok(STATE_CONFIGS.busy.amplitude >= 128);
  assert.ok(STATE_CONFIGS.idle.amplitude >= 34);
  assert.ok(STATE_CONFIGS.busy.amplitude > STATE_CONFIGS.idle.amplitude * 2.5);
  assert.ok(STATE_CONFIGS.busy.glowStdDeviation > STATE_CONFIGS.idle.glowStdDeviation);
  assert.ok(WAVE_CYCLES <= 2.6);
});

test('wave path spans the visible drawing area', () => {
  const path = generateWavePath(STATE_CONFIGS.busy);

  assert.match(path, /^M 16 /);
  assert.match(path, / 496 /);
});

test('generated svg includes circular composition and waveform path', () => {
  const svg = generateLogoSvg('busy');

  assert.match(svg, /viewBox="0 0 512 512"/);
  assert.match(svg, /clipPath id="circle-clip"/);
  assert.match(svg, /id="waveform-path"/);
  assert.match(svg, /stroke="#[0-9a-fA-F]{6}"/);
});

test('export filenames are stable for both supported states', () => {
  assert.equal(getExportFilename('busy', 'svg'), 'app_state_busy.svg');
  assert.equal(getExportFilename('idle', 'png'), 'app_state_idle.png');
});

test('app icon set specs include the 1024px marketing icon', () => {
  assert.ok(Array.isArray(APP_ICONSET_SPECS));
  assert.ok(APP_ICONSET_SPECS.some((entry) => entry.filename === 'icon_512x512@2x.png' && entry.pixelSize === 1024));
});
