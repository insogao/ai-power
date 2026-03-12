const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const {
  APP_ICONSET_SPECS,
  STATE_CONFIGS,
  generateLogoSvg,
  getExportFilename
} = require('./logo_generator.js');

const ROOT = path.resolve(__dirname, '..');
const EXPORT_DIR = path.join(ROOT, 'Assets', 'AppStateIcons');
const ASSET_CATALOG_DIR = path.join(ROOT, 'Sources', 'AIPowerApp', 'Assets.xcassets');
const APP_ICONSET_DIR = path.join(ASSET_CATALOG_DIR, 'AppIcon.appiconset');

function ensureDir(directory) {
  fs.mkdirSync(directory, { recursive: true });
}

function writeFile(filePath, contents) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, contents);
}

function renderPngFromSvg(svgPath, pngPath, size) {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-power-logo-'));

  try {
    execFileSync('/usr/bin/qlmanage', ['-t', '-s', String(size), '-o', tempDir, svgPath], { stdio: 'pipe' });
    const quickLookOutput = path.join(tempDir, `${path.basename(svgPath)}.png`);

    if (!fs.existsSync(quickLookOutput)) {
      throw new Error(`Quick Look did not produce a PNG for ${svgPath}`);
    }

    fs.copyFileSync(quickLookOutput, pngPath);
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

function resizePng(sourcePngPath, destinationPngPath, pixelSize) {
  execFileSync('/usr/bin/sips', ['-z', String(pixelSize), String(pixelSize), sourcePngPath, '--out', destinationPngPath], { stdio: 'pipe' });
}

function writeAssetCatalogMetadata() {
  writeFile(
    path.join(ASSET_CATALOG_DIR, 'Contents.json'),
    JSON.stringify({
      info: {
        author: 'xcode',
        version: 1
      }
    }, null, 2) + '\n'
  );

  writeFile(
    path.join(APP_ICONSET_DIR, 'Contents.json'),
    JSON.stringify({
      images: APP_ICONSET_SPECS.map(({ idiom, size, scale, filename }) => ({
        idiom,
        size,
        scale,
        filename
      })),
      info: {
        author: 'xcode',
        version: 1
      }
    }, null, 2) + '\n'
  );
}

function exportStateAssets(stateKey) {
  const svgPath = path.join(EXPORT_DIR, getExportFilename(stateKey, 'svg'));
  const pngPath = path.join(EXPORT_DIR, getExportFilename(stateKey, 'png'));

  writeFile(svgPath, generateLogoSvg(stateKey));
  renderPngFromSvg(svgPath, pngPath, 1024);

  return { svgPath, pngPath };
}

function exportAppIconset(masterPngPath) {
  ensureDir(APP_ICONSET_DIR);

  for (const spec of APP_ICONSET_SPECS) {
    resizePng(masterPngPath, path.join(APP_ICONSET_DIR, spec.filename), spec.pixelSize);
  }

  writeAssetCatalogMetadata();
}

function main() {
  ensureDir(EXPORT_DIR);

  for (const stateKey of Object.keys(STATE_CONFIGS)) {
    exportStateAssets(stateKey);
  }

  const busyPngPath = path.join(EXPORT_DIR, getExportFilename('busy', 'png'));
  exportAppIconset(busyPngPath);

  process.stdout.write(`Exported state icons to ${EXPORT_DIR}\n`);
  process.stdout.write(`Updated app icon set at ${APP_ICONSET_DIR}\n`);
}

main();
