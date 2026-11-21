import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { Scale, Sparkles } from 'lucide-react';

interface LegalScales3DProps {
  className?: string;
  tiltRatio?: number; // -1 (qattiq mijozga zarar) to +1, 0 = muvozanat
  isFixed?: boolean;
}

export const LegalScales3D: React.FC<LegalScales3DProps> = ({
  className = 'h-52 w-full',
  tiltRatio = -0.6,
  isFixed = false,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!containerRef.current) return;
    const container = containerRef.current;
    const width = container.clientWidth || 300;
    const height = container.clientHeight || 200;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(40, width / height, 0.1, 100);
    camera.position.set(0, 1.2, 5.5);

    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    // Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 1.2);
    scene.add(ambientLight);

    const mainLight = new THREE.DirectionalLight(0x38bdf8, 2.5);
    mainLight.position.set(5, 8, 5);
    scene.add(mainLight);

    const goldLight = new THREE.PointLight(0xf59e0b, 2, 20);
    goldLight.position.set(0, 2, 3);
    scene.add(goldLight);

    // Metallic Materials
    const goldMaterial = new THREE.MeshStandardMaterial({
      color: isFixed ? 0x10b981 : 0xd97706, // Emerald when fixed, Gold when reviewing
      metalness: 0.9,
      roughness: 0.2,
    });

    const standMaterial = new THREE.MeshStandardMaterial({
      color: 0x334155,
      metalness: 0.8,
      roughness: 0.3,
    });

    // 1. Base Stand
    const baseGeom = new THREE.CylinderGeometry(0.8, 0.9, 0.15, 32);
    const baseMesh = new THREE.Mesh(baseGeom, standMaterial);
    baseMesh.position.y = -1.2;
    scene.add(baseMesh);

    // 2. Central Pillar
    const pillarGeom = new THREE.CylinderGeometry(0.08, 0.1, 2.2, 24);
    const pillarMesh = new THREE.Mesh(pillarGeom, standMaterial);
    pillarMesh.position.y = -0.1;
    scene.add(pillarMesh);

    // 3. Central Pivot Sphere
    const pivotSphere = new THREE.Mesh(
      new THREE.SphereGeometry(0.18, 24, 24),
      goldMaterial
    );
    pivotSphere.position.y = 0.95;
    scene.add(pivotSphere);

    // 4. Tilting Beam (Tarozining ko'ndalang dastasi)
    const beamGroup = new THREE.Group();
    beamGroup.position.y = 0.95;
    scene.add(beamGroup);

    const beamGeom = new THREE.CylinderGeometry(0.05, 0.05, 3.2, 16);
    const beamMesh = new THREE.Mesh(beamGeom, goldMaterial);
    beamMesh.rotation.z = Math.PI / 2;
    beamGroup.add(beamMesh);

    // Left Pan Group (Mijoz / Fuqaro)
    const leftPanGroup = new THREE.Group();
    leftPanGroup.position.set(-1.5, 0, 0);
    beamGroup.add(leftPanGroup);

    const panGeom = new THREE.CylinderGeometry(0.5, 0.05, 0.15, 32);
    const leftPan = new THREE.Mesh(panGeom, goldMaterial);
    leftPan.position.y = -0.8;
    leftPanGroup.add(leftPan);

    // Right Pan Group (Kompaniya / Qarshi taraf)
    const rightPanGroup = new THREE.Group();
    rightPanGroup.position.set(1.5, 0, 0);
    beamGroup.add(rightPanGroup);

    const rightPan = new THREE.Mesh(panGeom, goldMaterial);
    rightPan.position.y = -0.8;
    rightPanGroup.add(rightPan);

    // Strings for pans
    const stringMat = new THREE.LineBasicMaterial({ color: 0x94a3b8 });
    const createStrings = (group: THREE.Group) => {
      const pts = [
        new THREE.Vector3(0, 0, 0),
        new THREE.Vector3(-0.35, -0.75, 0),
        new THREE.Vector3(0, 0, 0),
        new THREE.Vector3(0.35, -0.75, 0),
      ];
      const lineGeom = new THREE.BufferGeometry().setFromPoints(pts);
      const line = new THREE.LineSegments(lineGeom, stringMat);
      group.add(line);
    };

    createStrings(leftPanGroup);
    createStrings(rightPanGroup);

    // Target tilt angle
    // If fixed: balanced (0 rad). If not fixed, tilt based on tiltRatio (-0.35 rad)
    const targetTilt = isFixed ? 0 : tiltRatio * 0.4;
    let currentTilt = 0;

    let animId: number;
    let clock = new THREE.Clock();

    const animate = () => {
      animId = requestAnimationFrame(animate);
      const time = clock.getElapsedTime();

      // Smooth damping interpolation towards targetTilt
      currentTilt += (targetTilt - currentTilt) * 0.05;
      beamGroup.rotation.z = currentTilt + Math.sin(time * 2) * 0.02;

      // Keep pans hanging upright regardless of beam rotation
      leftPanGroup.rotation.z = -beamGroup.rotation.z;
      rightPanGroup.rotation.z = -beamGroup.rotation.z;

      // Gentle scene sway
      scene.rotation.y = Math.sin(time * 0.5) * 0.15;

      renderer.render(scene, camera);
    };

    animate();

    const handleResize = () => {
      if (!container) return;
      const w = container.clientWidth;
      const h = container.clientHeight;
      if (w === 0 || h === 0) return;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    };

    window.addEventListener('resize', handleResize);

    return () => {
      cancelAnimationFrame(animId);
      window.removeEventListener('resize', handleResize);
      scene.traverse((obj) => {
        if (obj instanceof THREE.Mesh) {
          obj.geometry?.dispose();
          if (Array.isArray(obj.material)) {
            obj.material.forEach((mat) => mat.dispose());
          } else if (obj.material) {
            obj.material.dispose();
          }
        }
      });
      renderer.dispose();
      if (renderer.domElement && container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
    };
  }, [tiltRatio, isFixed]);

  return (
    <div className={`relative rounded-3xl bg-slate-900/60 border border-slate-800 shadow-xl overflow-hidden flex flex-col items-center justify-center p-3 ${className}`}>
      <div className="absolute top-3 left-4 flex items-center gap-2 z-10">
        <Scale className={`w-4 h-4 ${isFixed ? 'text-emerald-400' : 'text-amber-400'}`} />
        <span className="text-xs font-bold text-white">
          {isFixed ? '3D Muvozanat: 50 / 50 (Qonuniy)' : '3D Asimmetriya Ko‘rsatkichi'}
        </span>
      </div>

      <div ref={containerRef} className="w-full h-full" />

      <div className="absolute bottom-2.5 inset-x-4 flex items-center justify-between text-[10px] font-mono text-slate-400 z-10 pointer-events-none">
        <span className={isFixed ? 'text-emerald-400 font-bold' : 'text-rose-400 font-bold'}>
          ◄ Mijoz Majburiyatlari
        </span>
        <span className={isFixed ? 'text-emerald-400 font-bold' : 'text-sky-400 font-bold'}>
          Ijrochi Majburiyatlari ►
        </span>
      </div>
    </div>
  );
};
