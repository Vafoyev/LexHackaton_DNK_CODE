#!/usr/bin/env node
// ==============================================================================
// LexGuard AI 3.0 — 3D Model Generator (Three.js Extrude + GLTF/GLB Exporter)
// Generates 3D meshes from SVG vectors: Lex.uz logo, Shield, Scales, Padlock
// ==============================================================================

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import * as THREE from '../front/node_modules/three/build/three.module.js';
import { SVGLoader } from '../front/node_modules/three/examples/jsm/loaders/SVGLoader.js';
import { GLTFExporter } from '../front/node_modules/three/examples/jsm/exporters/GLTFExporter.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');
const MODELS_DIR = path.resolve(ROOT_DIR, 'front', 'public', 'models');

if (!fs.existsSync(MODELS_DIR)) {
  fs.mkdirSync(MODELS_DIR, { recursive: true });
}

// ── Node.js DOM shims for Three.js SVG and GLTF Exporter ──────────────────────
class MockElement {
  constructor(nodeName, attrs = {}, children = []) {
    this.nodeName = nodeName;
    this.nodeType = 1;
    this.attrs = attrs;
    this.childNodes = children;
    this.children = children;
  }
  hasAttribute(name) { return name in this.attrs; }
  getAttribute(name) { return this.attrs[name] || null; }
}

globalThis.DOMParser = class MockDOMParser {
  parseFromString(text) {
    const dMatch = text.match(/\bd="([^"]+)"/s);
    const d = dMatch ? dMatch[1] : '';
    const pathNode = new MockElement('path', { d, fill: '#0064A9' });
    const gNode = new MockElement('g', {}, [pathNode]);
    const svgNode = new MockElement('svg', { viewBox: '0 0 8690.18 2587.69' }, [gNode]);
    return { documentElement: svgNode };
  }
};

globalThis.FileReader = class MockFileReader {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then((buf) => {
      this.result = buf;
      if (this.onloadend) this.onloadend();
    });
  }
  readAsDataURL(blob) {
    blob.arrayBuffer().then((buf) => {
      this.result = 'data:application/octet-stream;base64,' + Buffer.from(buf).toString('base64');
      if (this.onloadend) this.onloadend();
    });
  }
};

console.log('🚀 LexGuard 3D Model Generation starting...');

// ── 1. Generate Lex.uz 3D Logo (GLTF & GLB) ───────────────────────────────────
function generateLexUz3D() {
  const svgPath = path.resolve(ROOT_DIR, 'front', 'public', 'lex_uz.svg');
  if (!fs.existsSync(svgPath)) {
    console.error('❌ lex_uz.svg not found at', svgPath);
    return;
  }

  const svgContent = fs.readFileSync(svgPath, 'utf-8');
  const loader = new SVGLoader();
  const parsed = loader.parse(svgContent);
  const shapes = SVGLoader.createShapes(parsed.paths[0]);

  const group = new THREE.Group();
  group.name = 'LexUz_3D_Logo';

  const extrudeSettings = {
    depth: 120,
    bevelEnabled: true,
    bevelSegments: 4,
    steps: 1,
    bevelSize: 12,
    bevelThickness: 12,
  };

  const blueMaterial = new THREE.MeshStandardMaterial({
    color: 0x0064a9,
    metalness: 0.82,
    roughness: 0.22,
    name: 'LexUz_Blue_Metallic',
  });

  shapes.forEach((shape) => {
    const geom = new THREE.ExtrudeGeometry(shape, extrudeSettings);
    geom.computeVertexNormals();
    const mesh = new THREE.Mesh(geom, blueMaterial);
    group.add(mesh);
  });

  // Center and normalize size
  const box = new THREE.Box3().setFromObject(group);
  const size = new THREE.Vector3();
  box.getSize(size);
  const center = new THREE.Vector3();
  box.getCenter(center);

  const targetWidth = 10;
  const scale = targetWidth / size.x;
  group.scale.set(scale, -scale, scale);
  group.position.set(-center.x * scale, center.y * scale, 0);

  const scene = new THREE.Scene();
  scene.name = 'LexUz_Scene';
  scene.add(group);

  const exporter = new GLTFExporter();
  
  // Export GLTF
  exporter.parse(
    scene,
    (gltf) => {
      const gltfOut = path.resolve(MODELS_DIR, 'lex_uz.gltf');
      fs.writeFileSync(gltfOut, JSON.stringify(gltf, null, 2));
      console.log('✅ Generated GLTF: front/public/models/lex_uz.gltf (' + (fs.statSync(gltfOut).size / 1024).toFixed(1) + ' KB)');
    },
    (err) => console.error('GLTF error:', err),
    { binary: false, embedImages: true }
  );

  // Export GLB (Binary)
  exporter.parse(
    scene,
    (glb) => {
      const glbOut = path.resolve(MODELS_DIR, 'lex_uz.glb');
      fs.writeFileSync(glbOut, Buffer.from(glb));
      console.log('✅ Generated GLB:  front/public/models/lex_uz.glb  (' + (fs.statSync(glbOut).size / 1024).toFixed(1) + ' KB)');
    },
    (err) => console.error('GLB error:', err),
    { binary: true }
  );
}

// ── Run generator ─────────────────────────────────────────────────────────────
generateLexUz3D();
