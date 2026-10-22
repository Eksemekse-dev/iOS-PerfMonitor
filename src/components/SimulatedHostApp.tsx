import React, { useEffect, useRef, useState } from 'react';
import { Play, Pause, Zap, Activity, ShieldCheck, Box } from 'lucide-react';

interface SimulatedHostAppProps {
  onFpsUpdate: (fps: number) => void;
  cpuLoadFactor: number;
  onSetCpuLoadFactor: (factor: number) => void;
  isStressTesting: boolean;
  allocatedStressMB: number;
}

export const SimulatedHostApp: React.FC<SimulatedHostAppProps> = ({
  onFpsUpdate,
  cpuLoadFactor,
  onSetCpuLoadFactor,
  isStressTesting,
  allocatedStressMB,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [isRunning, setIsRunning] = useState(true);
  const [activeTab, setActiveTab] = useState<'game' | 'livecontainer'>('game');

  // Physics particles simulation
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animationFrameId: number;
    let lastTime = performance.now();
    let frameCount = 0;
    let fpsTimer = performance.now();

    // Particle count scaled by cpuLoadFactor (100 to 1200 particles)
    const count = Math.floor(120 * cpuLoadFactor);
    const particles = Array.from({ length: count }, () => ({
      x: Math.random() * 400,
      y: Math.random() * 500,
      vx: (Math.random() - 0.5) * 3 * cpuLoadFactor,
      vy: (Math.random() - 0.5) * 3 * cpuLoadFactor,
      radius: Math.random() * 2.5 + 1.5,
      hue: Math.random() * 360,
    }));

    const render = (time: number) => {
      const dt = (time - lastTime) / 1000;
      lastTime = time;
      frameCount++;

      if (time - fpsTimer >= 500) {
        const currentFps = Math.min(60, Math.round((frameCount * 1000) / (time - fpsTimer)));
        onFpsUpdate(currentFps);
        frameCount = 0;
        fpsTimer = time;
      }

      // Resize canvas to match display size
      if (canvas.width !== canvas.clientWidth || canvas.height !== canvas.clientHeight) {
        canvas.width = canvas.clientWidth;
        canvas.height = canvas.clientHeight;
      }

      // Draw background
      ctx.fillStyle = '#090a10';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Draw grid lines
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.04)';
      ctx.lineWidth = 1;
      const gridSize = 30;
      for (let x = 0; x < canvas.width; x += gridSize) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, canvas.height);
        ctx.stroke();
      }
      for (let y = 0; y < canvas.height; y += gridSize) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(canvas.width, y);
        ctx.stroke();
      }

      // Draw particles & connections
      const pLen = particles.length;
      for (let i = 0; i < pLen; i++) {
        const p = particles[i];
        p.x += p.vx;
        p.y += p.vy;

        if (p.x < 0 || p.x > canvas.width) p.vx *= -1;
        if (p.y < 0 || p.y > canvas.height) p.vy *= -1;

        ctx.fillStyle = `hsl(${p.hue}, 80%, 60%)`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fill();

        // Connect nearby particles if under load
        if (i % 3 === 0) {
          for (let j = i + 1; j < Math.min(i + 6, pLen); j++) {
            const p2 = particles[j];
            const dist = Math.hypot(p.x - p2.x, p.y - p2.y);
            if (dist < 60) {
              ctx.strokeStyle = `hsla(${p.hue}, 80%, 60%, ${1 - dist / 60})`;
              ctx.beginPath();
              ctx.moveTo(p.x, p.y);
              ctx.lineTo(p2.x, p2.y);
              ctx.stroke();
            }
          }
        }
      }

      // If heavy load factor, do minor math loop to emulate real thread stress
      if (cpuLoadFactor > 2) {
        let dummy = 0;
        for (let k = 0; k < 15000 * cpuLoadFactor; k++) {
          dummy += Math.sin(k);
        }
      }

      if (isRunning) {
        animationFrameId = requestAnimationFrame(render);
      }
    };

    animationFrameId = requestAnimationFrame(render);
    return () => cancelAnimationFrame(animationFrameId);
  }, [isRunning, cpuLoadFactor, onFpsUpdate]);

  return (
    <div className="relative w-full h-full flex flex-col bg-[#0b0d14] text-white select-none overflow-hidden">
      {/* App Bar / LiveContainer Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-[#131622]/90 border-b border-white/10 shrink-0">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded-lg bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center shadow-md">
            <Box className="w-3.5 h-3.5 text-white" />
          </div>
          <div>
            <div className="text-xs font-bold leading-tight">LiveContainer App</div>
            <div className="text-[10px] text-cyan-400 font-mono">Dylib Hook: PerfMonitor.dylib</div>
          </div>
        </div>

        <div className="flex items-center gap-1.5 bg-black/40 p-0.5 rounded-lg border border-white/10">
          <button
            onClick={() => setActiveTab('game')}
            className={`px-2.5 py-1 rounded-md text-[11px] font-semibold transition-all ${
              activeTab === 'game'
                ? 'bg-blue-600 text-white shadow'
                : 'text-neutral-400 hover:text-white'
            }`}
          >
            Renderer
          </button>
          <button
            onClick={() => setActiveTab('livecontainer')}
            className={`px-2.5 py-1 rounded-md text-[11px] font-semibold transition-all ${
              activeTab === 'livecontainer'
                ? 'bg-blue-600 text-white shadow'
                : 'text-neutral-400 hover:text-white'
            }`}
          >
            Container Log
          </button>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="relative flex-1 overflow-hidden">
        {activeTab === 'game' ? (
          <div className="relative w-full h-full">
            <canvas ref={canvasRef} className="w-full h-full block" />

            {/* Overlay Status info */}
            <div className="absolute bottom-4 left-4 right-4 flex flex-col gap-2 pointer-events-auto">
              {isStressTesting && (
                <div className="p-3 rounded-xl bg-red-950/80 border border-red-500/50 backdrop-blur-md animate-pulse">
                  <div className="flex items-center justify-between text-xs font-bold text-red-300">
                    <span className="flex items-center gap-1.5">
                      <Zap className="w-4 h-4 text-red-400 animate-bounce" />
                      Active RAM Stress Test
                    </span>
                    <span className="font-mono text-sm">{allocatedStressMB} MB Allocated</span>
                  </div>
                  <div className="w-full h-2 mt-2 bg-black/50 rounded-full overflow-hidden">
                    <div
                      style={{ width: `${Math.min(100, (allocatedStressMB / 3000) * 100)}%` }}
                      className="h-full bg-gradient-to-r from-orange-500 to-red-600 transition-all duration-150"
                    />
                  </div>
                </div>
              )}

              {/* Host App Stress Load Controls */}
              <div className="p-3 rounded-2xl bg-[#141724]/90 backdrop-blur-md border border-white/10 flex items-center justify-between gap-3 shadow-xl">
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setIsRunning(!isRunning)}
                    className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-colors"
                    title={isRunning ? 'Pause Engine' : 'Resume Engine'}
                  >
                    {isRunning ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                  </button>
                  <div>
                    <div className="text-[11px] font-bold text-neutral-200">Host Workload</div>
                    <div className="text-[10px] text-neutral-400">
                      {cpuLoadFactor === 1 ? '1x (Normal)' : cpuLoadFactor === 2 ? '2x (Elevated)' : '4x (High Stress)'}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-1.5">
                  {[1, 2, 4].map((factor) => (
                    <button
                      key={factor}
                      onClick={() => onSetCpuLoadFactor(factor)}
                      className={`px-2.5 py-1 rounded-lg text-[11px] font-bold font-mono transition-all ${
                        cpuLoadFactor === factor
                          ? 'bg-cyan-500 text-black shadow-md shadow-cyan-500/30'
                          : 'bg-white/5 text-neutral-400 hover:text-white hover:bg-white/10'
                      }`}
                    >
                      {factor}x
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="p-4 h-full overflow-y-auto space-y-3 font-mono text-xs text-neutral-300">
            <div className="p-3 rounded-xl bg-white/[0.04] border border-white/10 space-y-1.5">
              <div className="flex items-center gap-1.5 text-cyan-400 font-bold text-[11px] uppercase tracking-wider">
                <ShieldCheck className="w-4 h-4" />
                LiveContainer Sandbox Status
              </div>
              <p className="text-[11px] text-neutral-400 font-sans">
                LiveContainer allows unsigned iOS apps to execute dynamic code by leveraging JIT and
                tweak injection via dlopen() without requiring a full jailbreak.
              </p>
            </div>

            <div className="p-3 rounded-xl bg-black/60 border border-white/10 space-y-1 text-[11px]">
              <div className="text-emerald-400 font-bold">[TweakLoader] Loaded PerfMonitor.dylib</div>
              <div className="text-neutral-400">[MachKernel] Initialized task_info & task_threads hooks</div>
              <div className="text-neutral-400">[UIWindow] Created alert overlay UIWindow (Level: Alert+1000)</div>
              <div className="text-cyan-400">[Gestures] 4-finger UITapGestureRecognizer registered</div>
              <div className="text-cyan-400">[Gestures] 4-finger UILongPressGestureRecognizer registered</div>
              <div className="text-purple-400">[Telemetry] mach_task_self resident_size stream active</div>
            </div>

            <div className="p-3 rounded-xl bg-white/[0.04] border border-white/10 space-y-1.5 text-[11px]">
              <div className="font-bold text-neutral-200">Anti-Debugging Check</div>
              <p className="text-neutral-400">
                ptrace check executed with <code className="text-cyan-300">PT_DENY_ATTACH</code> and sysctl{' '}
                <code className="text-cyan-300">P_TRACED</code>. Status: Clean.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
