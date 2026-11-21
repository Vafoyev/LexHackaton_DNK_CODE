import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { Sparkles, RotateCw, Maximize2 } from 'lucide-react';

interface LexUz3DLogoProps {
  className?: string;
  autoRotate?: boolean;
  interactive?: boolean;
  size?: 'sm' | 'md' | 'lg' | 'hero';
}

export const LexUz3DLogo: React.FC<LexUz3DLogoProps> = ({
  className = '',
  autoRotate = true,
  interactive = true,
  size = 'md',
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isHovered, setIsHovered] = useState(false);

  useEffect(() => {
    if (!containerRef.current) return;
    const container = containerRef.current;
    const width = container.clientWidth || 240;
    const height = container.clientHeight || 160;

    // 1. Scene
    const scene = new THREE.Scene();

    // 2. Camera
    const camera = new THREE.PerspectiveCamera(38, width / height, 0.1, 1000);
    camera.position.set(0, 0, 14);

    // 3. Renderer
    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.2;
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    // 4. Lighting (Professional Cyber-Legal studio light)
    const ambientLight = new THREE.AmbientLight(0xffffff, 1.2);
    scene.add(ambientLight);

    const dirLight1 = new THREE.DirectionalLight(0x38bdf8, 2.5); // Sky cyan light
    dirLight1.position.set(10, 12, 10);
    scene.add(dirLight1);

    const dirLight2 = new THREE.DirectionalLight(0x0284c7, 1.8); // Deep blue rim light
    dirLight2.position.set(-10, -8, -6);
    scene.add(dirLight2);

    const pointLight = new THREE.PointLight(0x68acd7, 3, 50);
    pointLight.position.set(0, 4, 8);
    scene.add(pointLight);

    // 5. Star/Glow Particles in background
    const particleCount = 40;
    const particleGeometry = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount * 3; i += 3) {
      particlePositions[i] = (Math.random() - 0.5) * 18;
      particlePositions[i + 1] = (Math.random() - 0.5) * 10;
      particlePositions[i + 2] = (Math.random() - 0.5) * 8 - 2;
    }
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));
    const particleMaterial = new THREE.PointsMaterial({
      color: 0x38bdf8,
      size: 0.12,
      transparent: true,
      opacity: 0.6,
      blending: THREE.AdditiveBlending,
    });
    const particles = new THREE.Points(particleGeometry, particleMaterial);
    scene.add(particles);

    // 6. Root Pivot Group
    const modelGroup = new THREE.Group();
    scene.add(modelGroup);

    // 7. Load GLTF / GLB Model
    const loader = new GLTFLoader();
    let isDisposed = false;

    loader.load(
      '/models/lex_uz.glb',
      (gltf) => {
        if (isDisposed) return;
        const model = gltf.scene;

        // Enhance metallic shader materials
        model.traverse((child) => {
          if ((child as THREE.Mesh).isMesh) {
            const mesh = child as THREE.Mesh;
            mesh.material = new THREE.MeshStandardMaterial({
              color: 0x0064a9,
              metalness: 0.88,
              roughness: 0.18,
              emissive: 0x001a33,
              emissiveIntensity: 0.2,
            });
            mesh.castShadow = true;
            mesh.receiveShadow = true;
          }
        });

        modelGroup.add(model);
        setIsLoading(false);
      },
      undefined,
      (error) => {
        console.warn('Fallback loading procedural model', error);
        setIsLoading(false);
      }
    );

    // 8. Interactive Mouse Tracking
    let targetRotationX = 0;
    let targetRotationY = 0;

    const handleMouseMove = (e: MouseEvent) => {
      if (!interactive) return;
      const rect = container.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      const y = -(((e.clientY - rect.top) / rect.height) * 2 - 1);
      targetRotationY = x * 0.45;
      targetRotationX = -y * 0.35;
    };

    if (interactive) {
      container.addEventListener('mousemove', handleMouseMove);
    }

    // 9. Animation Loop
    let animationFrameId: number;
    let clock = new THREE.Clock();

    const animate = () => {
      animationFrameId = requestAnimationFrame(animate);
      const elapsedTime = clock.getElapsedTime();

      // Soft breathing motion
      modelGroup.position.y = Math.sin(elapsedTime * 1.5) * 0.15;

      if (autoRotate && !isHovered) {
        modelGroup.rotation.y += 0.008;
        modelGroup.rotation.x = Math.sin(elapsedTime * 0.8) * 0.08;
      } else {
        modelGroup.rotation.y += (targetRotationY - modelGroup.rotation.y) * 0.08;
        modelGroup.rotation.x += (targetRotationX - modelGroup.rotation.x) * 0.08;
      }

      // Rotate subtle particles
      particles.rotation.y = elapsedTime * 0.03;

      renderer.render(scene, camera);
    };

    animate();

    // 10. Resize handler
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
      isDisposed = true;
      cancelAnimationFrame(animationFrameId);
      window.removeEventListener('resize', handleResize);
      if (interactive) {
        container.removeEventListener('mousemove', handleMouseMove);
      }
      renderer.dispose();
      particleGeometry.dispose();
      particleMaterial.dispose();
    };
  }, [autoRotate, interactive, isHovered]);

  const heightClasses = {
    sm: 'h-24 w-36',
    md: 'h-40 w-full max-w-[280px]',
    lg: 'h-64 w-full',
    hero: 'h-80 w-full',
  }[size];

  return (
    <div
      className={`relative rounded-3xl bg-gradient-to-b from-slate-900/40 via-slate-950/60 to-slate-950 border border-slate-800/80 shadow-2xl overflow-hidden flex items-center justify-center group ${heightClasses} ${className}`}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* 3D Canvas Container */}
      <div ref={containerRef} className="w-full h-full cursor-grab active:cursor-grabbing" />

      {/* Loading Skeleton */}
      {isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-slate-950/80 backdrop-blur-sm">
          <div className="flex items-center gap-2 text-xs font-mono text-sky-400">
            <RotateCw className="w-4 h-4 animate-spin" />
            <span>3D Model Yuklanmoqda...</span>
          </div>
        </div>
      )}

      {/* 3D Emblema Badge */}
      <div className="absolute top-2.5 left-3 pointer-events-none flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-slate-900/80 border border-sky-500/30 text-[9px] font-mono text-sky-400">
        <Sparkles className="w-3 h-3 text-sky-400" />
        <span>3D GLTF / WebGL</span>
      </div>
    </div>
  );
};
