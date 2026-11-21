import React, { useEffect, useRef, useState } from 'react';
import { Button } from '../ui/button';
import * as THREE from 'three';
import { AnalysisResult, ContractClause, RiskLevel } from '../../types/contract';
import { 
  RotateCw, 
  ZoomIn, 
  ZoomOut, 
  Eye, 
  Info, 
  Sparkles, 
  Filter, 
  ChevronRight,
  Maximize2,
  Minimize2,
  Layers,
  Compass
} from 'lucide-react';

interface Contract3DVisualizerProps {
  analysis: AnalysisResult;
  selectedClauseId?: string | null;
  onSelectClause: (clauseId: string) => void;
}

export const Contract3DVisualizer: React.FC<Contract3DVisualizerProps> = ({
  analysis,
  selectedClauseId,
  onSelectClause,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [hoveredClause, setHoveredClause] = useState<ContractClause | null>(null);
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });
  const [autoRotate, setAutoRotate] = useState(true);
  const [filterRisk, setFilterRisk] = useState<RiskLevel | 'ALL'>('ALL');
  const [focusedClause, setFocusedClause] = useState<ContractClause | null>(null);
  const [layoutMode, setLayoutMode] = useState<'SPHERICAL' | 'CLUSTERED' | 'HELIX'>('SPHERICAL');
  const [isFullscreen, setIsFullscreen] = useState(false);

  // Three.js instances ref
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const nodesGroupRef = useRef<THREE.Group | null>(null);
  const coreOrbRef = useRef<THREE.Mesh | null>(null);
  const dynamicLightRef = useRef<THREE.PointLight | null>(null);
  const animationFrameIdRef = useRef<number | null>(null);
  const isDraggingRef = useRef(false);
  const prevMousePosRef = useRef({ x: 0, y: 0 });
  const targetCameraPosRef = useRef<THREE.Vector3 | null>(null);
  const targetLookAtRef = useRef<THREE.Vector3>(new THREE.Vector3(0, 0, 0));
  const currentLookAtRef = useRef<THREE.Vector3>(new THREE.Vector3(0, 0, 0));

  // Ranglar matritsasi
  const getColorForRisk = (risk: RiskLevel): number => {
    switch (risk) {
      case 'RED': return 0xDC2626;     // Qizil (Huquqiy ziddiyat)
      case 'YELLOW': return 0xD97706;  // Sariq (Tijoriy asimmetriya)
      case 'GREEN': return 0x16A34A;   // Yashil (Muvozanatli)
      case 'GRAY': return 0x6B7280;    // Kulrang (Advokat ko'rigi)
      default: return 0x0284C7;
    }
  };

  useEffect(() => {
    if (!containerRef.current) return;
    const container = containerRef.current;
    const width = container.clientWidth;
    const height = container.clientHeight || 580;

    // 1. Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;
    scene.fog = new THREE.FogExp2(0x060B18, 0.002);

    // 2. Camera
    const camera = new THREE.PerspectiveCamera(50, width / height, 0.1, 1000);
    camera.position.set(0, 30, 85);
    camera.lookAt(0, 0, 0);
    cameraRef.current = camera;

    // 3. WebGL Renderer
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.3;
    rendererRef.current = renderer;
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    // 4. Lights & Dynamic Cursor Light
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.9);
    scene.add(ambientLight);

    const dirLight1 = new THREE.DirectionalLight(0x38BDF8, 2.2);
    dirLight1.position.set(30, 45, 30);
    scene.add(dirLight1);

    const dirLight2 = new THREE.DirectionalLight(0x22C55E, 1.8);
    dirLight2.position.set(-30, -35, -30);
    scene.add(dirLight2);

    // Dynamic mouse-following point light for immersion
    const dynamicLight = new THREE.PointLight(0x38BDF8, 3.5, 90);
    dynamicLight.position.set(0, 20, 50);
    scene.add(dynamicLight);
    dynamicLightRef.current = dynamicLight;

    // 5. Starfield / Nebula Particles
    const particleCount = 600;
    const particleGeometry = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(particleCount * 3);
    const particleColors = new Float32Array(particleCount * 3);

    for (let i = 0; i < particleCount * 3; i += 3) {
      particlePositions[i] = (Math.random() - 0.5) * 250;
      particlePositions[i + 1] = (Math.random() - 0.5) * 250;
      particlePositions[i + 2] = (Math.random() - 0.5) * 250;

      // Moviy va zumrad rangli kosmik nurlar
      particleColors[i] = 0.2 + Math.random() * 0.3;     // R
      particleColors[i + 1] = 0.6 + Math.random() * 0.4; // G
      particleColors[i + 2] = 0.9;                       // B
    }
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));
    particleGeometry.setAttribute('color', new THREE.BufferAttribute(particleColors, 3));

    const particleMaterial = new THREE.PointsMaterial({
      size: 1.4,
      vertexColors: true,
      transparent: true,
      opacity: 0.5,
      blending: THREE.AdditiveBlending,
    });
    const starField = new THREE.Points(particleGeometry, particleMaterial);
    scene.add(starField);

    // 6. Central Core Orb (Shartnoma Markaziy Risk Sferasi)
    const coreGroup = new THREE.Group();
    const coreRiskColor = analysis.summary.risk_score > 60 ? 0xDC2626 : analysis.summary.risk_score > 30 ? 0xD97706 : 0x16A34A;
    
    // Core Sphere
    const coreGeo = new THREE.IcosahedronGeometry(7.5, 3);
    const coreMat = new THREE.MeshStandardMaterial({
      color: coreRiskColor,
      roughness: 0.15,
      metalness: 0.85,
      emissive: coreRiskColor,
      emissiveIntensity: 0.4,
    });
    const coreOrb = new THREE.Mesh(coreGeo, coreMat);
    coreOrbRef.current = coreOrb;
    coreGroup.add(coreOrb);

    // Outer Wireframe Hologram
    const wireGeo = new THREE.IcosahedronGeometry(9.5, 2);
    const wireMat = new THREE.MeshBasicMaterial({
      color: 0x38BDF8,
      wireframe: true,
      transparent: true,
      opacity: 0.28,
    });
    const wireMesh = new THREE.Mesh(wireGeo, wireMat);
    coreGroup.add(wireMesh);

    // Outer Glow Rings
    const ringGeo = new THREE.RingGeometry(11.5, 12.2, 64);
    const ringMat = new THREE.MeshBasicMaterial({
      color: 0x38BDF8,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: 0.45,
    });
    const ringMesh1 = new THREE.Mesh(ringGeo, ringMat);
    ringMesh1.rotation.x = Math.PI / 2;
    coreGroup.add(ringMesh1);

    const ringMesh2 = new THREE.Mesh(ringGeo, ringMat);
    ringMesh2.rotation.y = Math.PI / 2;
    coreGroup.add(ringMesh2);

    scene.add(coreGroup);

    // 7. Clause Nodes & Layout calculation
    const nodesGroup = new THREE.Group();
    nodesGroupRef.current = nodesGroup;
    scene.add(nodesGroup);

    const clauses = analysis.clauses || [];
    const totalClauses = clauses.length;
    const baseRadius = 29;

    clauses.forEach((clause, index) => {
      let x = 0;
      let y = 0;
      let z = 0;

      if (layoutMode === 'SPHERICAL') {
        const phi = Math.acos(-1 + (2 * index) / Math.max(totalClauses, 1));
        const theta = Math.sqrt(totalClauses * Math.PI) * phi;
        x = baseRadius * Math.cos(theta) * Math.sin(phi);
        y = baseRadius * Math.sin(theta) * Math.sin(phi) * 0.75;
        z = baseRadius * Math.cos(phi);
      } else if (layoutMode === 'CLUSTERED') {
        // Xavf darajasiga qarab 3D fazoviy klasterlash
        let heightLayer = 0;
        let clusterRadius = 25;
        if (clause.risk_level === 'RED') {
          heightLayer = 18;
          clusterRadius = 20;
        } else if (clause.risk_level === 'YELLOW') {
          heightLayer = 6;
          clusterRadius = 28;
        } else if (clause.risk_level === 'GREEN') {
          heightLayer = -12;
          clusterRadius = 32;
        } else {
          heightLayer = -2;
          clusterRadius = 24;
        }
        const angle = (index / totalClauses) * Math.PI * 2 * 2;
        x = clusterRadius * Math.cos(angle);
        y = heightLayer + Math.sin(index) * 2;
        z = clusterRadius * Math.sin(angle);
      } else {
        // HELIX (DNK spiral tartibi)
        const helixRadius = 24;
        const helixAngle = (index / totalClauses) * Math.PI * 6;
        x = helixRadius * Math.cos(helixAngle);
        y = -20 + (index / totalClauses) * 40;
        z = helixRadius * Math.sin(helixAngle);
      }

      const nodeColor = getColorForRisk(clause.risk_level);
      const isRisky = clause.risk_level === 'RED' || clause.risk_level === 'YELLOW';
      const nodeSize = clause.risk_level === 'RED' ? 2.8 : clause.risk_level === 'YELLOW' ? 2.2 : 1.7;

      const nodeGeo = new THREE.SphereGeometry(nodeSize, 28, 28);
      const nodeMat = new THREE.MeshStandardMaterial({
        color: nodeColor,
        roughness: 0.25,
        metalness: 0.7,
        emissive: nodeColor,
        emissiveIntensity: isRisky ? 0.75 : 0.25,
      });

      const nodeMesh = new THREE.Mesh(nodeGeo, nodeMat);
      nodeMesh.position.set(x, y, z);
      nodeMesh.userData = { clause, index, originalPos: { x, y, z } };

      // Xavfli tugun atrofida halo / aura
      if (isRisky) {
        const haloGeo = new THREE.SphereGeometry(nodeSize * 1.5, 18, 18);
        const haloMat = new THREE.MeshBasicMaterial({
          color: nodeColor,
          wireframe: true,
          transparent: true,
          opacity: 0.38,
        });
        const haloMesh = new THREE.Mesh(haloGeo, haloMat);
        nodeMesh.add(haloMesh);
      }

      nodesGroup.add(nodeMesh);

      // Curved Spline / Line Markaziy yadro bilan bog'lovchi nur
      const midPoint = new THREE.Vector3(x * 0.5, y * 0.5 + (isRisky ? 4 : -2), z * 0.5);
      const curve = new THREE.QuadraticBezierCurve3(
        new THREE.Vector3(0, 0, 0),
        midPoint,
        new THREE.Vector3(x, y, z)
      );
      const points = curve.getPoints(20);
      const lineGeo = new THREE.BufferGeometry().setFromPoints(points);
      const lineMat = new THREE.LineBasicMaterial({
        color: nodeColor,
        transparent: true,
        opacity: isRisky ? 0.5 : 0.18,
      });
      const line = new THREE.Line(lineGeo, lineMat);
      nodesGroup.add(line);
    });

    // 8. Interaktivlik (Raycaster, Mouse Drag Rotation)
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2();

    const onPointerMove = (e: MouseEvent) => {
      const rect = container.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      const y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
      mouse.x = x;
      mouse.y = y;

      setMousePos({ x: e.clientX - rect.left, y: e.clientY - rect.top });

      // Dinamik nur sichqoncha ortidan siljiydi
      if (dynamicLightRef.current) {
        dynamicLightRef.current.position.x = x * 40;
        dynamicLightRef.current.position.y = y * 40;
      }

      if (isDraggingRef.current) {
        const deltaX = e.clientX - prevMousePosRef.current.x;
        const deltaY = e.clientY - prevMousePosRef.current.y;
        if (nodesGroupRef.current) {
          nodesGroupRef.current.rotation.y += deltaX * 0.008;
          nodesGroupRef.current.rotation.x += deltaY * 0.008;
        }
        prevMousePosRef.current = { x: e.clientX, y: e.clientY };
      } else {
        // Raycast hover tekshirish
        raycaster.setFromCamera(mouse, camera);
        if (nodesGroupRef.current) {
          const nodeMeshes = nodesGroupRef.current.children.filter(c => c instanceof THREE.Mesh);
          const intersects = raycaster.intersectObjects(nodeMeshes, false);
          if (intersects.length > 0) {
            const hit = intersects[0].object;
            const clause = hit.userData.clause as ContractClause;
            if (clause) {
              setHoveredClause(clause);
              container.style.cursor = 'pointer';
              return;
            }
          }
        }
        setHoveredClause(null);
        container.style.cursor = isDraggingRef.current ? 'grabbing' : 'grab';
      }
    };

    const onMouseDown = (e: MouseEvent) => {
      isDraggingRef.current = true;
      prevMousePosRef.current = { x: e.clientX, y: e.clientY };
      container.style.cursor = 'grabbing';
    };

    const onMouseUp = () => {
      isDraggingRef.current = false;
      container.style.cursor = 'grab';
    };

    const onClick = () => {
      raycaster.setFromCamera(mouse, camera);
      if (nodesGroupRef.current) {
        const nodeMeshes = nodesGroupRef.current.children.filter(c => c instanceof THREE.Mesh);
        const intersects = raycaster.intersectObjects(nodeMeshes, false);
        if (intersects.length > 0) {
          const hit = intersects[0].object as THREE.Mesh;
          const clause = hit.userData.clause as ContractClause;
          if (clause) {
            setFocusedClause(clause);
            onSelectClause(clause.id);

            // Smooth Lerp: Kamera ushbu tugun tomon mayin yaqinlashadi
            const worldPos = new THREE.Vector3();
            hit.getWorldPosition(worldPos);
            targetLookAtRef.current.copy(worldPos);
            // Kamera tugundan biroz uzoqlikda, lekin yaqin fokusda turadi
            const offset = worldPos.clone().normalize().multiplyScalar(18);
            targetCameraPosRef.current = worldPos.clone().add(offset.length() > 0 ? offset : new THREE.Vector3(0, 5, 20));
          }
        }
      }
    };

    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      camera.position.z = Math.min(Math.max(camera.position.z + e.deltaY * 0.08, 30), 160);
    };

    container.addEventListener('mousemove', onPointerMove);
    container.addEventListener('mousedown', onMouseDown);
    window.addEventListener('mouseup', onMouseUp);
    container.addEventListener('click', onClick);
    container.addEventListener('wheel', onWheel, { passive: false });

    // 9. Animatsiya Tsikli
    let clock = new THREE.Clock();
    const animate = () => {
      const elapsed = clock.getElapsedTime();

      // Core Orb nafas olish effekti
      if (coreOrbRef.current) {
        const scale = 1 + Math.sin(elapsed * 2.2) * 0.06;
        coreOrbRef.current.scale.set(scale, scale, scale);
      }
      coreGroup.rotation.y = elapsed * 0.12;
      wireMesh.rotation.x = elapsed * 0.08;
      ringMesh1.rotation.z = elapsed * 0.18;
      ringMesh2.rotation.x = elapsed * 0.15;

      // Smooth Camera Lerp Harakati
      if (targetCameraPosRef.current && cameraRef.current) {
        cameraRef.current.position.lerp(targetCameraPosRef.current, 0.05);
        currentLookAtRef.current.lerp(targetLookAtRef.current, 0.05);
        cameraRef.current.lookAt(currentLookAtRef.current);

        // Agar yetib borgan bo'lsa lerpni to'xtatamiz
        if (cameraRef.current.position.distanceTo(targetCameraPosRef.current) < 0.2) {
          targetCameraPosRef.current = null;
        }
      }

      // Tugunlar guruhi avtomatik aylanishi (agar fokuslanmagan bo'lsa)
      if (nodesGroupRef.current && autoRotate && !isDraggingRef.current && !targetCameraPosRef.current) {
        nodesGroupRef.current.rotation.y += 0.0025;
      }

      // Zarralar tebranishi
      starField.rotation.y = elapsed * 0.015;

      renderer.render(scene, camera);
      animationFrameIdRef.current = requestAnimationFrame(animate);
    };
    animate();

    // 10. Resize observer
    const resizeObserver = new ResizeObserver(() => {
      if (!containerRef.current) return;
      const w = containerRef.current.clientWidth;
      const h = containerRef.current.clientHeight || 580;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    });
    resizeObserver.observe(container);

    // Cleanup
    return () => {
      if (animationFrameIdRef.current) {
        cancelAnimationFrame(animationFrameIdRef.current);
      }
      container.removeEventListener('mousemove', onPointerMove);
      container.removeEventListener('mousedown', onMouseDown);
      window.removeEventListener('mouseup', onMouseUp);
      container.removeEventListener('click', onClick);
      container.removeEventListener('wheel', onWheel);
      resizeObserver.disconnect();

      // Zero-Leak Cleanup: Dispose all geometries, materials, and textures
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
      starField.geometry.dispose();
      (starField.material as THREE.Material).dispose();
      renderer.dispose();
      if (renderer.domElement && container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
    };
  }, [analysis, autoRotate, layoutMode]);

  // Filtr o'zgarganda tugunlar ko'rinishini sozlash
  useEffect(() => {
    if (!nodesGroupRef.current) return;
    nodesGroupRef.current.children.forEach(child => {
      if (child instanceof THREE.Mesh && child.userData.clause) {
        const clause = child.userData.clause as ContractClause;
        if (filterRisk === 'ALL' || clause.risk_level === filterRisk) {
          child.visible = true;
        } else {
          child.visible = false;
        }
      }
    });
  }, [filterRisk]);

  // Reset kamera pozitsiyasi (Smooth qaytish)
  const handleResetCamera = () => {
    targetCameraPosRef.current = new THREE.Vector3(0, 30, 85);
    targetLookAtRef.current = new THREE.Vector3(0, 0, 0);
    if (nodesGroupRef.current) {
      nodesGroupRef.current.rotation.set(0, 0, 0);
    }
  };

  const handleZoom = (delta: number) => {
    if (cameraRef.current) {
      cameraRef.current.position.z = Math.min(Math.max(cameraRef.current.position.z + delta, 35), 140);
    }
  };

  return (
    <div className={`relative w-full ${isFullscreen ? 'fixed inset-0 z-50 h-screen' : 'h-[620px] rounded-3xl'} bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 border border-slate-800 shadow-2xl overflow-hidden select-none transition-all`}>
      {/* 3D WebGL Canvas */}
      <div ref={containerRef} className="w-full h-full cursor-grab" />

      {/* Header Info Overlay */}
      <div className="absolute top-4 left-4 z-20 flex flex-col gap-1.5 pointer-events-none">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-xl bg-zinc-500/20 text-zinc-400 border border-zinc-500/30 backdrop-blur-md shadow-lg shadow-zinc-500/20">
            <Sparkles className="w-4 h-4 animate-spin-slow" />
          </div>
          <div>
            <h3 className="text-sm font-black text-white tracking-wide flex items-center gap-2">
              <span>3D Immersion Risk Visualizer</span>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-zinc-500/10 text-zinc-400 border border-zinc-500/30">
                Three.js WebGL
              </span>
            </h3>
            <p className="text-[11px] text-slate-400">
              {analysis.clauses.length} ta shartnoma bandi fazoviy koordinatalarda aks ettirilgan
            </p>
          </div>
        </div>
      </div>

      {/* Layout Mode Selector (Yuqori Markazda) */}
      <div className="absolute top-4 left-1/2 -translate-x-1/2 z-20 flex items-center gap-1 bg-slate-900/90 backdrop-blur-md p-1 rounded-xl border border-slate-800 shadow-xl">
        <Button
          type="button"
          size="sm"
          variant={layoutMode === 'SPHERICAL' ? 'default' : 'ghost'}
          aria-pressed={layoutMode === 'SPHERICAL'}
          onClick={() => setLayoutMode('SPHERICAL')}
          title="Sferik fazoviy joylashuv"
          className={`h-8 gap-1.5 text-xs font-semibold ${layoutMode === 'SPHERICAL' ? '' : 'text-slate-300 hover:text-white'}`}
        >
          <Compass className="h-3.5 w-3.5" aria-hidden="true" />
          Sferik
        </Button>

        <Button
          type="button"
          size="sm"
          variant={layoutMode === 'CLUSTERED' ? 'default' : 'ghost'}
          aria-pressed={layoutMode === 'CLUSTERED'}
          onClick={() => setLayoutMode('CLUSTERED')}
          title="Xavf darajasi bo'yicha qatlamlarga ajratish"
          className={`h-8 gap-1.5 text-xs font-semibold ${layoutMode === 'CLUSTERED' ? '' : 'text-slate-300 hover:text-white'}`}
        >
          <Layers className="h-3.5 w-3.5" aria-hidden="true" />
          Risk qatlamlari
        </Button>

        <Button
          type="button"
          size="sm"
          variant={layoutMode === 'HELIX' ? 'default' : 'ghost'}
          aria-pressed={layoutMode === 'HELIX'}
          onClick={() => setLayoutMode('HELIX')}
          title="Shartnoma DNK spirali"
          className={`h-8 gap-1.5 text-xs font-semibold ${layoutMode === 'HELIX' ? '' : 'text-slate-300 hover:text-white'}`}
        >
          <Sparkles className="h-3.5 w-3.5" aria-hidden="true" />
          DNK spiral
        </Button>
      </div>

      {/* Floating Risk Indicators (O'ng burchak) */}
      <div className="absolute top-4 right-4 z-20 flex flex-col items-end gap-2">
        <div className="flex items-center gap-2 bg-slate-900/90 backdrop-blur-md px-3.5 py-2 rounded-xl border border-slate-800 shadow-lg">
          <div className="text-right">
            <div className="text-[10px] uppercase font-bold text-slate-400 tracking-wider">Shartnoma Xavf Indeksi</div>
            <div className="text-xl font-black text-white flex items-center justify-end gap-1">
              <span className={analysis.summary.risk_score > 60 ? 'text-red-400' : analysis.summary.risk_score > 30 ? 'text-amber-400' : 'text-emerald-400'}>
                {analysis.summary.risk_score}
              </span>
              <span className="text-xs text-slate-500 font-normal">/ 100</span>
            </div>
          </div>
          <div className={`w-3.5 h-3.5 rounded-full animate-ping ${analysis.summary.risk_score > 60 ? 'bg-red-500' : 'bg-amber-500'}`} />
        </div>

        {/* 4-Rangli Filterlar */}
        <div className="flex items-center gap-1 bg-slate-900/80 backdrop-blur-md p-1 rounded-lg border border-slate-800/80">
          <Button
            type="button"
            size="sm"
            variant={filterRisk === 'ALL' ? 'secondary' : 'ghost'}
            aria-pressed={filterRisk === 'ALL'}
            onClick={() => setFilterRisk('ALL')}
            className="h-7 gap-1 px-2 text-[11px] font-semibold"
          >
            Barchasi ({analysis.clauses.length})
          </Button>
          <Button
            type="button"
            size="sm"
            variant={filterRisk === 'RED' ? 'secondary' : 'ghost'}
            aria-pressed={filterRisk === 'RED'}
            onClick={() => setFilterRisk('RED')}
            className="h-7 gap-1 px-2 text-[11px] font-semibold"
          >
            <span className="h-2 w-2 rounded-full bg-red-500" aria-hidden="true" />
            Qizil ({analysis.summary.red_count})
          </Button>
          <Button
            type="button"
            size="sm"
            variant={filterRisk === 'YELLOW' ? 'secondary' : 'ghost'}
            aria-pressed={filterRisk === 'YELLOW'}
            onClick={() => setFilterRisk('YELLOW')}
            className="h-7 gap-1 px-2 text-[11px] font-semibold"
          >
            <span className="h-2 w-2 rounded-full bg-amber-500" aria-hidden="true" />
            Sariq ({analysis.summary.yellow_count})
          </Button>
          <Button
            type="button"
            size="sm"
            variant={filterRisk === 'GREEN' ? 'secondary' : 'ghost'}
            aria-pressed={filterRisk === 'GREEN'}
            onClick={() => setFilterRisk('GREEN')}
            className="h-7 gap-1 px-2 text-[11px] font-semibold"
          >
            <span className="h-2 w-2 rounded-full bg-emerald-500" aria-hidden="true" />
            Yashil ({analysis.summary.green_count})
          </Button>
        </div>
      </div>

      {/* Control Buttons (Pastki chap) */}
      <div className="absolute bottom-4 left-4 z-20 flex items-center gap-1.5 bg-slate-900/90 backdrop-blur-md p-1.5 rounded-xl border border-slate-800 shadow-xl">
        <Button
          type="button"
          size="icon"
          variant="ghost"
          aria-pressed={autoRotate}
          onClick={() => setAutoRotate(!autoRotate)}
          title={autoRotate ? "Avtomatik aylanishni to'xtatish" : "Avtomatik aylanishni yoqish"}
          aria-label={autoRotate ? "Avtomatik aylanishni to'xtatish" : "Avtomatik aylanishni yoqish"}
          className="h-8 w-8 text-slate-300 hover:text-white {autoRotate ? 'bg-slate-800 text-zinc-400' : ''}"
        >
          <RotateCw className={`h-4 w-4 ${autoRotate ? 'animate-spin-slow' : ''}`} aria-hidden="true" />
        </Button>

        <Button
          type="button"
          size="icon"
          variant="ghost"
          onClick={() => handleZoom(-15)}
          title="Yaqinlashtirish"
          aria-label="Yaqinlashtirish"
          className="h-8 w-8 text-slate-300 hover:text-white "
        >
          <ZoomIn className="h-4 w-4" aria-hidden="true" />
        </Button>

        <Button
          type="button"
          size="icon"
          variant="ghost"
          onClick={() => handleZoom(15)}
          title="Uzoqlashtirish"
          aria-label="Uzoqlashtirish"
          className="h-8 w-8 text-slate-300 hover:text-white "
        >
          <ZoomOut className="h-4 w-4" aria-hidden="true" />
        </Button>

        <Button type="button" size="sm" variant="ghost" onClick={handleResetCamera} title="Kamera holatini tiklash" className="h-8 gap-1 px-2.5 text-xs font-medium text-slate-300 hover:text-white">
          <Eye className="h-3.5 w-3.5 text-zinc-400" aria-hidden="true" />
          Reset
        </Button>

        <Button
          type="button"
          size="icon"
          variant="ghost"
          onClick={() => setIsFullscreen(!isFullscreen)}
          title={isFullscreen ? "Kichik ekranga qaytish" : "To'liq ekran rejimiga o'tish"}
          aria-label={isFullscreen ? "Kichik ekranga qaytish" : "To'liq ekran rejimiga o'tish"}
          className="h-8 w-8 text-slate-300 hover:text-white "
        >
          {isFullscreen ? <Minimize2 className="h-4 w-4" aria-hidden="true" /> : <Maximize2 className="h-4 w-4" aria-hidden="true" />}
        </Button>
      </div>

      {/* Pastki o'ngdagi mini qo'llanma */}
      <div className="absolute bottom-4 right-4 z-20 pointer-events-none hidden sm:block">
        <div className="bg-slate-900/80 backdrop-blur-md px-3 py-1.5 rounded-lg border border-slate-800 text-[11px] text-slate-400 flex items-center gap-2">
          <Info className="w-3.5 h-3.5 text-zinc-400" />
          <span>Sichqoncha bilan aylantiring · Tugun ustiga bosing</span>
        </div>
      </div>

      {/* Hover Tooltip (Raycaster yordamida) */}
      {hoveredClause && (
        <div 
          className="absolute z-30 pointer-events-none transition-all duration-75"
          style={{
            left: `${Math.min(mousePos.x + 15, containerRef.current ? containerRef.current.clientWidth - 320 : 400)}px`,
            top: `${Math.min(mousePos.y + 15, containerRef.current ? containerRef.current.clientHeight - 180 : 350)}px`,
          }}
        >
          <div className="w-72 p-3 bg-slate-900/95 backdrop-blur-xl rounded-xl border border-slate-700 shadow-2xl">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs font-bold text-white flex items-center gap-1.5">
                <span className={`w-2.5 h-2.5 rounded-full ${
                  hoveredClause.risk_level === 'RED' ? 'bg-red-500' :
                  hoveredClause.risk_level === 'YELLOW' ? 'bg-amber-500' :
                  hoveredClause.risk_level === 'GREEN' ? 'bg-emerald-500' : 'bg-gray-500'
                }`} />
                {hoveredClause.clause_number}-band: {hoveredClause.title}
              </span>
              <span className={`text-[10px] uppercase font-bold px-1.5 py-0.5 rounded ${
                hoveredClause.risk_level === 'RED' ? 'bg-red-500/20 text-red-400' :
                hoveredClause.risk_level === 'YELLOW' ? 'bg-amber-500/20 text-amber-400' :
                hoveredClause.risk_level === 'GREEN' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-gray-500/20 text-gray-400'
              }`}>
                {hoveredClause.risk_level}
              </span>
            </div>
            <p className="text-[11px] text-slate-300 line-clamp-3 italic mb-2">
              "{hoveredClause.original_text}"
            </p>
            <div className="text-[10px] text-zinc-400 font-medium flex items-center gap-1">
              <span>Batafsil ko'rish uchun bosing</span>
              <ChevronRight className="w-3 h-3" />
            </div>
          </div>
        </div>
      )}

      {/* Tanlangan band haqida dialog/modal ko'rinishi */}
      {focusedClause && (
        <div className="absolute top-16 left-4 z-30 max-w-sm p-4 bg-slate-900/95 backdrop-blur-xl rounded-2xl border border-zinc-500/40 shadow-2xl animate-in fade-in zoom-in-95 duration-200">
          <div className="flex items-start justify-between gap-2 mb-2">
            <div>
              <span className="text-[10px] uppercase font-bold text-zinc-400 tracking-wider">3D Fokuslangan Band</span>
              <h4 className="text-sm font-bold text-white">
                {focusedClause.clause_number}-band · {focusedClause.title}
              </h4>
            </div>
            <Button type="button" variant="ghost" size="icon" onClick={() => setFocusedClause(null)} className="h-7 w-7 text-slate-400 hover:text-white" aria-label="Yopish">
              ✕
            </Button>
          </div>
          <p className="text-xs text-slate-300 mb-3 bg-slate-950/60 p-2.5 rounded-lg border border-slate-800/80">
            "{focusedClause.original_text}"
          </p>
          <Button
            type="button"
            onClick={() => {
              onSelectClause(focusedClause.id);
              setFocusedClause(null);
            }}
            className="w-full gap-1.5 text-xs font-semibold"
          >
            Diff Viewer-da taqqoslash
            <ChevronRight className="h-4 w-4" aria-hidden="true" />
          </Button>
        </div>
      )}
    </div>
  );
};
