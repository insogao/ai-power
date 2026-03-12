(function initializeLogoGenerator(root) {
  const SIZE = 512;
  const CENTER = 256;
  const RADIUS = 240;
  const START_X = 16;
  const END_X = 496;
  const WAVE_STEPS = 400;
  const WAVE_CYCLES = 2.55;

  const STATE_CONFIGS = {
    busy: {
      key: 'busy',
      label: 'Busy',
      amplitude: 136,
      glowStdDeviation: 10,
      strokeColor: '#18e0c8',
      glowColor: '#65f1dd',
      ringColor: '#adc8db',
      gridColor: '#d7e3ef',
      fillStart: '#112334',
      fillEnd: '#09131f',
      axisOpacity: 0.28,
      gridOpacity: 0.26,
      ringOpacity: 0.7,
      lineOpacity: 0.98,
      strokeWidth: 17
    },
    idle: {
      key: 'idle',
      label: 'Idle',
      amplitude: 36,
      glowStdDeviation: 5.5,
      strokeColor: '#90a9c7',
      glowColor: '#ced9e7',
      ringColor: '#bfd0de',
      gridColor: '#dce6ef',
      fillStart: '#13202d',
      fillEnd: '#0d1621',
      axisOpacity: 0.18,
      gridOpacity: 0.18,
      ringOpacity: 0.56,
      lineOpacity: 0.9,
      strokeWidth: 14.5
    }
  };

  const APP_ICONSET_SPECS = [
    { idiom: 'mac', size: '16x16', scale: '1x', filename: 'icon_16x16.png', pixelSize: 16 },
    { idiom: 'mac', size: '16x16', scale: '2x', filename: 'icon_16x16@2x.png', pixelSize: 32 },
    { idiom: 'mac', size: '32x32', scale: '1x', filename: 'icon_32x32.png', pixelSize: 32 },
    { idiom: 'mac', size: '32x32', scale: '2x', filename: 'icon_32x32@2x.png', pixelSize: 64 },
    { idiom: 'mac', size: '128x128', scale: '1x', filename: 'icon_128x128.png', pixelSize: 128 },
    { idiom: 'mac', size: '128x128', scale: '2x', filename: 'icon_128x128@2x.png', pixelSize: 256 },
    { idiom: 'mac', size: '256x256', scale: '1x', filename: 'icon_256x256.png', pixelSize: 256 },
    { idiom: 'mac', size: '256x256', scale: '2x', filename: 'icon_256x256@2x.png', pixelSize: 512 },
    { idiom: 'mac', size: '512x512', scale: '1x', filename: 'icon_512x512.png', pixelSize: 512 },
    { idiom: 'mac', size: '512x512', scale: '2x', filename: 'icon_512x512@2x.png', pixelSize: 1024 }
  ];

  function getStateConfig(stateKey) {
    const config = STATE_CONFIGS[stateKey];
    if (!config) {
      throw new Error(`Unsupported logo state: ${stateKey}`);
    }
    return config;
  }

  function generateWavePath(stateOrConfig, phaseOffset = 0) {
    const config = typeof stateOrConfig === 'string' ? getStateConfig(stateOrConfig) : stateOrConfig;
    let path = '';

    for (let step = 0; step <= WAVE_STEPS; step += 1) {
      const t = step / WAVE_STEPS;
      const x = START_X + (END_X - START_X) * t;
      const phase = (2 * Math.PI * WAVE_CYCLES * t) - phaseOffset;
      const y = CENTER - config.amplitude * Math.sin(phase);

      if (step === 0) {
        path += `M ${x} ${y}`;
      } else {
        path += ` L ${x} ${y}`;
      }
    }

    return path;
  }

  function getExportFilename(stateKey, extension) {
    return `app_state_${stateKey}.${extension}`;
  }

  function generateLogoSvg(stateKey, options = {}) {
    const config = getStateConfig(stateKey);
    const phaseOffset = options.phaseOffset || 0;
    const pathData = generateWavePath(config, phaseOffset);
    const title = options.title || `AI Power ${config.label} logo`;

    return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}" aria-label="${title}">
  <defs>
    <radialGradient id="panel-fill" cx="34%" cy="30%" r="78%">
      <stop offset="0%" stop-color="${config.fillStart}" stop-opacity="0.72" />
      <stop offset="62%" stop-color="${config.fillEnd}" stop-opacity="0.5" />
      <stop offset="100%" stop-color="${config.fillEnd}" stop-opacity="0.14" />
    </radialGradient>
    <radialGradient id="panel-sheen" cx="30%" cy="24%" r="64%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.18" />
      <stop offset="52%" stop-color="#ffffff" stop-opacity="0.04" />
      <stop offset="100%" stop-color="#ffffff" stop-opacity="0" />
    </radialGradient>
    <filter id="wave-glow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="${config.glowStdDeviation}" result="blur" />
      <feFlood flood-color="${config.glowColor}" flood-opacity="0.55" result="flood" />
      <feComposite in="flood" in2="blur" operator="in" result="glow" />
      <feMerge>
        <feMergeNode in="glow" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
    <clipPath id="circle-clip">
      <circle cx="${CENTER}" cy="${CENTER}" r="${RADIUS}" />
    </clipPath>
  </defs>
  <g clip-path="url(#circle-clip)">
    <circle cx="${CENTER}" cy="${CENTER}" r="${RADIUS}" fill="url(#panel-fill)" />
    <circle cx="${CENTER}" cy="${CENTER}" r="${RADIUS}" fill="url(#panel-sheen)" />
    <g opacity="${config.gridOpacity}">
      <path d="${buildGridPaths()}" fill="none" stroke="${config.gridColor}" stroke-width="2" stroke-opacity="0.75" />
    </g>
    <line x1="${CENTER}" y1="${START_X}" x2="${CENTER}" y2="${END_X}" stroke="${config.ringColor}" stroke-width="2" opacity="${config.axisOpacity}" stroke-dasharray="8 10" />
    <line x1="${START_X}" y1="${CENTER}" x2="${END_X}" y2="${CENTER}" stroke="${config.ringColor}" stroke-width="2" opacity="${config.axisOpacity}" stroke-dasharray="8 10" />
    <path id="waveform-path" d="${pathData}" fill="none" stroke="${config.strokeColor}" stroke-opacity="${config.lineOpacity}" stroke-width="${config.strokeWidth}" stroke-linecap="round" stroke-linejoin="round" filter="url(#wave-glow)" />
  </g>
  <circle cx="${CENTER}" cy="${CENTER}" r="${RADIUS}" fill="none" stroke="${config.ringColor}" stroke-width="6" opacity="${config.ringOpacity}" />
</svg>`;
  }

  function buildGridPaths() {
    const commands = [];
    for (let y = 32; y <= SIZE; y += 32) {
      for (let x = 32; x <= SIZE; x += 32) {
        commands.push(`M ${x} ${y - 32} L ${x - 32} ${y - 32} ${x - 32} ${y}`);
      }
    }
    return commands.join(' ');
  }

  const logoGenerator = {
    APP_ICONSET_SPECS,
    STATE_CONFIGS,
    WAVE_CYCLES,
    generateWavePath,
    generateLogoSvg,
    getExportFilename
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = logoGenerator;
  }

  root.logoGenerator = logoGenerator;
}(typeof globalThis !== 'undefined' ? globalThis : window));
