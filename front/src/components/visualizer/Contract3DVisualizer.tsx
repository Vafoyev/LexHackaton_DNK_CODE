import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { AnalysisResult, ContractClause, RiskLevel } from '../../types/contract';
import { RotateCw, ZoomIn, ZoomOut, Eye, Info, Sparkles, Filter, ChevronRight } from 'lucide-react';

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

  // Three.js instances ref
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.PerspectiveCamera | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const nodesGroupRef = useRef<THREE.Group | null>(null);
  const coreOrbRef = useRef<THREE.Mesh | null>(null);
  const animationFrameIdRef = useRef<number | null>(null);
  const isDraggingRef = useRef(false);
  const prevMousePosRef = useRef({ x: 0, y: 0 });

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
    const height = container.clientHeight || 550;

    // 1. Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;
    scene.fog = new THREE.FogExp2(0x060B18, 0.0025);

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
    renderer.toneMappingExposure = 1.2;
    rendererRef.current = renderer;
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    // 4. Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.9);
    scene.add(ambientLight);

    const dirLight1 = new THREE.DirectionalLight(0x38BDF8, 2.0);
    dirLight1.position.set(20, 40, 30);
    scene.add(dirLight1);

    const dirLight2 = new THREE.DirectionalLight(0x22C55E, 1.5);
    dirLight2.position.set(-20, -30, -30);
    scene.add(dirLight2);

    // 5. Starfield / Ambient Particles
    const particleCount = 400;
    const particleGeometry = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount * 3; i += 3) {
      particlePositions[i] = (Math.random() - 0.5) * 200;
      particlePositions[i + 1] = (Math.random() - 0.5) * 200;
      particlePositions[i + 2] = (Math.random() - 0.5) * 200;
    }
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));
    const particleMaterial = new THREE.PointsMaterial({
      color: 0x38BDF8,
      size: 1.2,
      transparent: true,
      opacity: 0.4,
      blending: THREE.AdditiveBlending,
    });
    const starField = new THREE.Points(particleGeometry, particleMaterial);
    scene.add(starField);

    // 6. Central Core Orb (Shartnoma Markaziy Risk Sferasi)
    const coreGroup = new THREE.Group();
    const coreRiskColor = analysis.summary.risk_score > 60 ? 0xDC2626 : analysis.summary.risk_score > 30 ? 0xD97706 : 0x16A34A;
    
    // Core Sphere
    const coreGeo = new THREE.IcosahedronGeometry(7, 3);
    const coreMat = new THREE.MeshStandardMaterial({
      color: coreRiskColor,
      roughness: 0.2,
      metalness: 0.8,
      emissive: coreRiskColor,
      emissiveIntensity: 0.35,
      wireframe: false,
    });
    const coreOrb = new THREE.Mesh(coreGeo, coreMat);
    coreOrbRef.current = coreOrb;
    coreGroup.add(coreOrb);

    // Outer Wireframe Hologram
    const wireGeo = new THREE.IcosahedronGeometry(9, 2);
    const wireMat = new THREE.MeshBasicMaterial({
      color: 0x38BDF8,
      wireframe: true,
      transparent: true,
      opacity: 0.25,
    });
    const wireMesh = new THREE.Mesh(wireGeo, wireMat);
    coreGroup.add(wireMesh);

    // Outer Glow Ring
    const ringGeo = new THREE.RingGeometry(11, 11.5, 48);
    const ringMat = new THREE.MeshBasicMaterial({
      color: 0x38BDF8,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: 0.4,
    });
    const ringMesh = new THREE.Mesh(ringGeo, ringMat);
    ringMesh.rotation.x = Math.PI / 2;
    coreGroup.add(ringMesh);

    scene.add(coreGroup);

    // 7. Clause Nodes (Har bir shartnoma bandi 3D tuguni)
    const nodesGroup = new THREE.Group();
    nodesGroupRef.current = nodesGroup;
    scene.add(nodesGroup);

    const clauses = analysis.clauses || [];
    const totalClauses = clauses.length;
    const radius = 28;

    clauses.forEach((clause, index) => {
      // Sferik yoki spiral koordinata taqsimoti
      const phi = Math.acos(-1 + (2 * index) / Math.max(totalClauses, 1));
      const theta = Math.sqrt(totalClauses * Math.PI) * phi;

      const x = radius * Math.cos(theta) * Math.sin(phi);
      const y = radius * Math.sin(theta) * Math.sin(phi) * 0.7; // biroz ellips
      const z = radius * Math.cos(phi);

      const nodeColor = getColorForRisk(clause.risk_level);
      const isRisky = clause.risk_level === 'RED' || clause.risk_level === 'YELLOW';
      const nodeSize = isRisky ? 2.5 : 1.7;

      const nodeGeo = new THREE.SphereGeometry(nodeSize, 24, 24);
      const nodeMat = new THREE.MeshStandardMaterial({
        color: nodeColor,
        roughness: 0.3,
        metalness: 0.6,
        emissive: nodeColor,
        emissiveIntensity: isRisky ? 0.6 : 0.2,
      });

      const nodeMesh = new THREE.Mesh(nodeGeo, nodeMat);
      nodeMesh.position.set(x, y, z);
      nodeMesh.userData = { clause, index };

      // Tugun atrofida halo / glow xavfli bo'lsa
      if (isRisky) {
        const haloGeo = new THREE.SphereGeometry(nodeSize * 1.5, 16, 16);
        const haloMat = new THREE.MeshBasicMaterial({
          color: nodeColor,
          wireframe: true,
          transparent: true,
          opacity: 0.35,
        });
        const haloMesh = new THREE.Mesh(haloGeo, haloMat);
        nodeMesh.add(haloMesh);
      }

      nodesGroup.add(nodeMesh);

      // Markaziy yadro bilan bog'lovchi neon nur
      const lineGeo = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(0, 0, 0),
        new THREE.Vector3(x, y, z)
      ]);
      const lineMat = new THREE.LineBasicMaterial({
        color: nodeColor,
        transparent: true,
        opacity: isRisky ? 0.45 : 0.15,
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
          const hit = intersects[0].object;
          const clause = hit.userData.clause as ContractClause;
          if (clause) {
            setFocusedClause(clause);
            onSelectClause(clause.id);
          }
        }
      }
    };

    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      camera.position.z = Math.min(Math.max(camera.position.z + e.deltaY * 0.08, 30), 150);
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

      // Core Orb tebranishi
      if (coreOrbRef.current) {
        const scale = 1 + Math.sin(elapsed * 2) * 0.05;
        coreOrbRef.current.scale.set(scale, scale, scale);
      }
      coreGroup.rotation.y = elapsed * 0.15;
      wireMesh.rotation.x = elapsed * 0.1;
      ringMesh.rotation.z = elapsed * 0.2;

      // Tugunlar guruhi avtomatik aylanishi
      if (nodesGroupRef.current && autoRotate && !isDraggingRef.current) {
        nodesGroupRef.current.rotation.y += 0.003;
      }

      // Zarralar siljishi
      starField.rotation.y = elapsed * 0.02;

      renderer.render(scene, camera);
      animationFrameIdRef.current = requestAnimationFrame(animate);
    };
    animate();

    // 10. Resize observer
    const resizeObserver = new ResizeObserver(() => {
      if (!containerRef.current) return;
      const w = containerRef.current.clientWidth;
      const h = containerRef.current.clientHeight || 550;
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
      renderer.dispose();
    };
  }, [analysis, autoRotate]);

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

  // Reset kamera pozitsiyasi
  const handleResetCamera = () => {
    if (cameraRef.current && nodesGroupRef.current) {
      cameraRef.current.position.set(0, 30, 85);
      cameraRef.current.lookAt(0, 0, 0);
      nodesGroupRef.current.rotation.set(0, 0, 0);
    }
  };

  const handleZoom = (delta: number) => {
    if (cameraRef.current) {
      cameraRef.current.position.z = Math.min(Math.max(cameraRef.current.position.z + delta, 35), 130);
    }
  };

  return (
    <div className="relative w-full h-[580px] bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 rounded-2xl border border-slate-800 shadow-2xl overflow-hidden select-none">
      {/* 3D WebGL Canvas */}
      <div ref={containerRef} className="w-full h-full cursor-grab" />

      {/* Header Info Overlay */}
      <div className="absolute top-4 left-4 z-20 flex flex-col gap-1.5 pointer-events-none">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-sky-500/20 text-sky-400 border border-sky-500/30 backdrop-blur-md">
            <Sparkles className="w-4 h-4 animate-spin-slow" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-white tracking-wide flex items-center gap-2">
              Interaktiv 3D Shartnoma Risk Klasteri
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-800/80 text-sky-400 border border-slate-700">
                WebGL / Three.js
              </span>
            </h3>
            <p className="text-[11px] text-slate-400">
              Shartnomadagi {analysis.clauses.length} ta band fazoviy koordinatalarda aks ettirilgan
            </p>
          </div>
        </div>
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
          <button
            onClick={() => setFilterRisk('ALL')}
            className={`px-2 py-1 rounded text-[11px] font-semibold transition-all ${filterRisk === 'ALL' ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30' : 'text-slate-400 hover:text-white'}`}
          >
            Barchasi ({analysis.clauses.length})
          </button>
          <button
            onClick={() => setFilterRisk('RED')}
            className={`px-2 py-1 rounded text-[11px] font-semibold flex items-center gap-1 transition-all ${filterRisk === 'RED' ? 'bg-red-500/20 text-red-400 border border-red-500/30' : 'text-slate-400 hover:text-white'}`}
          >
            <span className="w-2 h-2 rounded-full bg-red-500"></span>
            Qizil ({analysis.summary.red_count})
          </button>
          <button
            onClick={() => setFilterRisk('YELLOW')}
            className={`px-2 py-1 rounded text-[11px] font-semibold flex items-center gap-1 transition-all ${filterRisk === 'YELLOW' ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' : 'text-slate-400 hover:text-white'}`}
          >
            <span className="w-2 h-2 rounded-full bg-amber-500"></span>
            Sariq ({analysis.summary.yellow_count})
          </button>
          <button
            onClick={() => setFilterRisk('GREEN')}
            className={`px-2 py-1 rounded text-[11px] font-semibold flex items-center gap-1 transition-all ${filterRisk === 'GREEN' ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30' : 'text-slate-400 hover:text-white'}`}
          >
            <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
            Yashil ({analysis.summary.green_count})
          </button>
        </div>
      </div>

      {/* Control Buttons (Pastki chap) */}
      <div className="absolute bottom-4 left-4 z-20 flex items-center gap-1.5 bg-slate-900/90 backdrop-blur-md p-1.5 rounded-xl border border-slate-800 shadow-xl">
        <button
          onClick={() => setAutoRotate(!autoRotate)}
          className={`p-2 rounded-lg text-xs font-medium transition-all ${
            autoRotate ? 'bg-sky-500/20 text-sky-400 border border-sky-500/30' : 'text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
          title={autoRotate ? "Avtomatik aylanishni to'xtatish" : "Avtomatik aylanishni yoqish"}
        >
          <RotateCw className={`w-4 h-4 ${autoRotate ? 'animate-spin-slow' : ''}`} />
        </button>

        <button
          onClick={() => handleZoom(-15)}
          className="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-all"
          title="Yaqinlashtirish"
        >
          <ZoomIn className="w-4 h-4" />
        </button>

        <button
          onClick={() => handleZoom(15)}
          className="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-all"
          title="Uzoqlashtirish"
        >
          <ZoomOut className="w-4 h-4" />
        </button>

        <button
          onClick={handleResetCamera}
          className="px-2.5 py-1.5 rounded-lg text-xs font-medium text-slate-300 hover:text-white hover:bg-slate-800 transition-all flex items-center gap-1"
          title="Kamera holatini tiklash"
        >
          <Eye className="w-3.5 h-3.5 text-sky-400" />
          <span>Reset</span>
        </button>
      </div>

      {/* Pastki o'ngdagi mini qo'llanma */}
      <div className="absolute bottom-4 right-4 z-20 pointer-events-none hidden sm:block">
        <div className="bg-slate-900/80 backdrop-blur-md px-3 py-1.5 rounded-lg border border-slate-800 text-[11px] text-slate-400 flex items-center gap-2">
          <Info className="w-3.5 h-3.5 text-sky-400" />
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
            <div className="text-[10px] text-sky-400 font-medium flex items-center gap-1">
              <span>Batafsil ko'rish uchun bosing</span>
              <ChevronRight className="w-3 h-3" />
            </div>
          </div>
        </div>
      )}

      {/* Tanlangan band haqida dialog/modal ko'rinishi */}
      {focusedClause && (
        <div className="absolute top-16 left-4 z-30 max-w-sm p-4 bg-slate-900/95 backdrop-blur-xl rounded-2xl border border-sky-500/40 shadow-2xl animate-in fade-in zoom-in-95 duration-200">
          <div className="flex items-start justify-between gap-2 mb-2">
            <div>
              <span className="text-[10px] uppercase font-bold text-sky-400 tracking-wider">3D Fokuslangan Band</span>
              <h4 className="text-sm font-bold text-white">
                {focusedClause.clause_number}-band · {focusedClause.title}
              </h4>
            </div>
            <button
              onClick={() => setFocusedClause(null)}
              className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800"
            >
              ✕
            </button>
          </div>
          <p className="text-xs text-slate-300 mb-3 bg-slate-950/60 p-2.5 rounded-lg border border-slate-800/80">
            "{focusedClause.original_text}"
          </p>
          <button
            onClick={() => {
              onSelectClause(focusedClause.id);
              setFocusedClause(null);
            }}
            className="w-full py-2 px-3 rounded-xl bg-gradient-to-r from-sky-600 to-brand-600 hover:from-sky-500 hover:to-brand-500 text-white font-semibold text-xs flex items-center justify-center gap-1.5 shadow-md shadow-sky-600/20 transition-all"
          >
            <span>Diff Viewer-da taqqoslash</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      )}
    </div>
  );
};
