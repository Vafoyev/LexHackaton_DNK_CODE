import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { AnalysisResult, RiskLevel } from '../../types/contract';

interface Mini3DVisualizerProps {
  analysis: AnalysisResult;
  onOpenFull3D?: () => void;
}

export const Mini3DVisualizer: React.FC<Mini3DVisualizerProps> = ({
  analysis,
  onOpenFull3D,
}) => {
  const mountRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!mountRef.current) return;
    const container = mountRef.current;
    const width = container.clientWidth || 280;
    const height = container.clientHeight || 180;

    // 1. Scene & Camera
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 100);
    camera.position.set(0, 5, 22);
    camera.lookAt(0, 0, 0);

    // 2. Renderer
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    // 3. Central Core Mesh (Icosahedron Wireframe + Inner Glow)
    const coreGeo = new THREE.IcosahedronGeometry(4.5, 2);
    const coreMat = new THREE.MeshBasicMaterial({
      color: 0x0284C7,
      wireframe: true,
      transparent: true,
      opacity: 0.35,
    });
    const coreMesh = new THREE.Mesh(coreGeo, coreMat);
    scene.add(coreMesh);

    // Inner Glow
    const innerGeo = new THREE.SphereGeometry(3.0, 16, 16);
    const innerMat = new THREE.MeshBasicMaterial({
      color: 0x38BDF8,
      transparent: true,
      opacity: 0.2,
    });
    const innerSphere = new THREE.Mesh(innerGeo, innerMat);
    scene.add(innerSphere);

    // 4. Risk Nodes in Orbit
    const nodeGroup = new THREE.Group();
    scene.add(nodeGroup);

    const getColorForRisk = (risk: RiskLevel) => {
      switch (risk) {
        case 'RED': return 0xEF4444;
        case 'YELLOW': return 0xF59E0B;
        case 'GREEN': return 0x10B981;
        default: return 0x64748B;
      }
    };

    analysis.clauses.forEach((clause, idx) => {
      const phi = Math.acos(-1 + (2 * idx) / analysis.clauses.length);
      const theta = Math.sqrt(analysis.clauses.length * Math.PI) * phi;
      const radius = 6.5;

      const x = radius * Math.cos(theta) * Math.sin(phi);
      const y = radius * Math.sin(theta) * Math.sin(phi);
      const z = radius * Math.cos(phi);

      const nodeGeo = new THREE.SphereGeometry(clause.risk_level === 'RED' ? 0.7 : 0.45, 12, 12);
      const nodeMat = new THREE.MeshBasicMaterial({
        color: getColorForRisk(clause.risk_level),
      });
      const node = new THREE.Mesh(nodeGeo, nodeMat);
      node.position.set(x, y, z);
      nodeGroup.add(node);

      // Bog'lovchi chiziq markazga
      const lineGeo = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(0, 0, 0),
        new THREE.Vector3(x, y, z),
      ]);
      const lineMat = new THREE.LineBasicMaterial({
        color: getColorForRisk(clause.risk_level),
        transparent: true,
        opacity: 0.25,
      });
      const line = new THREE.Line(lineGeo, lineMat);
      nodeGroup.add(line);
    });

    // 5. Starfield / Particles
    const particleCount = 80;
    const particleGeo = new THREE.BufferGeometry();
    const pos = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount * 3; i += 3) {
      pos[i] = (Math.random() - 0.5) * 40;
      pos[i + 1] = (Math.random() - 0.5) * 40;
      pos[i + 2] = (Math.random() - 0.5) * 40;
    }
    particleGeo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const particleMat = new THREE.PointsMaterial({
      color: 0x38BDF8,
      size: 0.8,
      transparent: true,
      opacity: 0.4,
    });
    const particles = new THREE.Points(particleGeo, particleMat);
    scene.add(particles);

    // 6. Animation loop
    let animId: number;
    const animate = () => {
      animId = requestAnimationFrame(animate);
      coreMesh.rotation.y += 0.005;
      coreMesh.rotation.x += 0.002;
      nodeGroup.rotation.y += 0.007;
      nodeGroup.rotation.x += 0.003;
      particles.rotation.y -= 0.001;
      renderer.render(scene, camera);
    };
    animate();

    return () => {
      cancelAnimationFrame(animId);
      renderer.dispose();
      if (container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
    };
  }, [analysis]);

  return (
    <div 
      onClick={onOpenFull3D}
      className="relative w-full h-44 rounded-2xl bg-slate-950/90 border border-slate-800 overflow-hidden cursor-pointer group hover:border-sky-500/50 transition-all flex items-center justify-center shadow-inner"
    >
      <div ref={mountRef} className="w-full h-full" />
      
      {/* 3D Badge */}
      <div className="absolute top-2.5 left-2.5 px-2 py-0.5 rounded-md bg-sky-500/20 text-sky-400 border border-sky-500/30 text-[10px] font-mono uppercase tracking-wider flex items-center gap-1">
        <span className="w-1.5 h-1.5 rounded-full bg-sky-400 animate-ping" />
        WebGL 3D Sfera
      </div>

      <div className="absolute bottom-2.5 right-2.5 px-2 py-0.5 rounded-md bg-slate-900/90 text-slate-300 border border-slate-700/80 text-[10px] font-semibold group-hover:text-sky-300 transition-colors">
        Kattalashtirish ↗
      </div>
    </div>
  );
};
