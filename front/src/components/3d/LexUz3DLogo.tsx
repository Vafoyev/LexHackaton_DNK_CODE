import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { Sparkles, RotateCw, Pause, Play, Eye } from 'lucide-react';

interface LexUz3DLogoProps {
  className?: string;
  autoRotate?: boolean;
  interactive?: boolean;
  size?: 'sm' | 'md' | 'lg' | 'hero';
  showControls?: boolean;
}

export const LexUz3DLogo: React.FC<LexUz3DLogoProps> = ({
  className = '',
  autoRotate: defaultAutoRotate = true,
  interactive = true,
  size = 'md',
  showControls = true,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRotating, setIsRotating] = useState(defaultAutoRotate);
  const [isHovered, setIsHovered] = useState(false);

  // References to keep across re-renders
  const modelGroupRef = useRef<THREE.Group | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;
    const container = containerRef.current;
    const width = container.clientWidth || 320;
    const height = container.clientHeight || 220;

    // 1. Scene
    const scene = new THREE.Scene();

    // 2. Camera (optimized FOV for full logo framing)
    const camera = new THREE.PerspectiveCamera(36, width / height, 0.1, 1000);
    camera.position.set(0, 0, 11.5);

    // 3. Renderer with high dynamic range PBR tone mapping
    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.35;
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    // 4. Lighting (Bright, Crisp Studio Specular Highlights)
    const ambientLight = new THREE.AmbientLight(0xffffff, 1.5);
    scene.add(ambientLight);

    // Main key light (Front-top right)
    const keyLight = new THREE.DirectionalLight(0xffffff, 3.5);
    keyLight.position.set(4, 8, 12);
    scene.add(keyLight);

    // Cyan fill light (Left rim)
    const cyanLight = new THREE.DirectionalLight(0x38bdf8, 2.5);
    cyanLight.position.set(-10, 4, 8);
    scene.add(cyanLight);

    // Deep blue bottom bounce light
    const bounceLight = new THREE.DirectionalLight(0x0284c7, 2.0);
    bounceLight.position.set(0, -8, 6);
    scene.add(bounceLight);

    // Point light center glow
    const pointLight = new THREE.PointLight(0x68acd7, 3.5, 30);
    pointLight.position.set(0, 0, 6);
    scene.add(pointLight);

    // 5. Ambient Cyber Dust Particles
    const particleCount = 45;
    const particleGeometry = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount * 3; i += 3) {
      particlePositions[i] = (Math.random() - 0.5) * 16;
      particlePositions[i + 1] = (Math.random() - 0.5) * 8;
      particlePositions[i + 2] = (Math.random() - 0.5) * 6 - 1;
    }
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));
    const particleMaterial = new THREE.PointsMaterial({
      color: 0x38bdf8,
      size: 0.12,
      transparent: true,
      opacity: 0.55,
      blending: THREE.AdditiveBlending,
    });
    const particles = new THREE.Points(particleGeometry, particleMaterial);
    scene.add(particles);

    // 6. Root Pivot Group
    const modelGroup = new THREE.Group();
    modelGroupRef.current = modelGroup;
    scene.add(modelGroup);

    // 7. Load GLTF / GLB Model
    const loader = new GLTFLoader();
    let isDisposed = false;

    loader.load(
      '/models/lex_uz.glb',
      (gltf) => {
        if (isDisposed) return;
        const model = gltf.scene;

        // Apply Lex.uz official sapphire metallic shader
        model.traverse((child) => {
          if ((child as THREE.Mesh).isMesh) {
            const mesh = child as THREE.Mesh;
            mesh.material = new THREE.MeshStandardMaterial({
              color: 0x0284c7,
              metalness: 0.85,
              roughness: 0.18,
              emissive: 0x002244,
              emissiveIntensity: 0.25,
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
      targetRotationY = x * 0.6;
      targetRotationX = -y * 0.45;
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
      modelGroup.position.y = Math.sin(elapsedTime * 1.5) * 0.12;

      if (isRotating && !isHovered) {
        modelGroup.rotation.y += 0.01;
        modelGroup.rotation.x = Math.sin(elapsedTime * 0.8) * 0.08;
      } else {
        modelGroup.rotation.y += (targetRotationY - modelGroup.rotation.y) * 0.08;
        modelGroup.rotation.x += (targetRotationX - modelGroup.rotation.x) * 0.08;
      }

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
  }, [isRotating, interactive, isHovered]);

  const heightClasses = {
    sm: 'h-28 w-44',
    md: 'h-48 w-full',
    lg: 'h-64 w-full',
    hero: 'h-80 sm:h-96 w-full',
  }[size];

  return (
    <div
      className={`relative rounded-3xl bg-gradient-to-b from-slate-900/30 via-slate-950/50 to-slate-950/80 border border-sky-500/20 shadow-2xl overflow-hidden flex items-center justify-center ${heightClasses} ${className}`}
    >
      {/* 3D Canvas Container */}
      <div ref={containerRef} className="w-full h-full pointer-events-none" />

      {/* Loading Skeleton */}
      {isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-slate-950/90 backdrop-blur-sm">
          <div className="flex items-center gap-2 text-xs font-mono text-sky-400">
            <RotateCw className="w-4 h-4 animate-spin" />
            <span>Yuklanmoqda...</span>
          </div>
        </div>
      )}
    </div>
  );
};
