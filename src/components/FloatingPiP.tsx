import React, { useState, useRef, useEffect } from 'react';
import { TelemetryData, PipSettings } from '../types.ts';
import { formatDec } from '../utils/telemetry.ts';
import { Maximize2 } from 'lucide-react';

interface FloatingPiPProps {
  telemetry: TelemetryData;
  settings: PipSettings;
  visible: boolean;
  onOpenDashboard: () => void;
  onToggleVisible: () => void;
  containerRef?: React.RefObject<HTMLDivElement | null>;
}

function hexToRgba(hex: string, alpha: number) {
  let c = hex.replace('#', '');
  if (c.length === 3) {
    c = c.split('').map((x) => x + x).join('');
  }
  const num = parseInt(c, 16);
  if (isNaN(num)) return `rgba(0, 0, 0, ${alpha})`;
  const r = (num >> 16) & 255;
  const g = (num >> 8) & 255;
  const b = num & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

export const FloatingPiP: React.FC<FloatingPiPProps> = ({
  telemetry,
  settings,
  visible,
  onOpenDashboard,
  containerRef,
}) => {
  // Default position: top centered
  const [position, setPosition] = useState<{ x: number; y: number }>({ x: 20, y: 75 });
  const [isDragging, setIsDragging] = useState(false);
  const dragStartRef = useRef<{ mouseX: number; mouseY: number; initialX: number; initialY: number }>({
    mouseX: 0,
    mouseY: 0,
    initialX: 0,
    initialY: 0,
  });

  // Calculate dynamic dimensions based on enabled items
  const activeMetricsCount = [
    settings.showCpu,
    settings.showRam,
    settings.showThermal,
    settings.showFps,
    settings.showModel,
  ].filter(Boolean).length;

  const pipHeight = Math.max(46, 26 + activeMetricsCount * 17);
  const pipWidth = activeMetricsCount >= 4 ? 152 : 142;

  // Keep within bounds on resize
  useEffect(() => {
    const handleResize = () => {
      const parent = containerRef?.current || document.body;
      const bounds = parent.getBoundingClientRect();
      setPosition((prev) => ({
        x: Math.max(10, Math.min(prev.x, bounds.width - pipWidth - 10)),
        y: Math.max(10, Math.min(prev.y, bounds.height - pipHeight - 10)),
      }));
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [containerRef, pipWidth, pipHeight]);

  const handlePointerDown = (e: React.PointerEvent) => {
    if (e.button !== 0 && e.pointerType === 'mouse') return;
    setIsDragging(true);
    dragStartRef.current = {
      mouseX: e.clientX,
      mouseY: e.clientY,
      initialX: position.x,
      initialY: position.y,
    };
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging) return;
    const dx = e.clientX - dragStartRef.current.mouseX;
    const dy = e.clientY - dragStartRef.current.mouseY;

    const parent = containerRef?.current || document.body;
    const bounds = parent.getBoundingClientRect();
    const maxX = Math.max(10, bounds.width - pipWidth - 5);
    const maxY = Math.max(10, bounds.height - pipHeight - 5);

    setPosition({
      x: Math.max(10, Math.min(dragStartRef.current.initialX + dx, maxX)),
      y: Math.max(10, Math.min(dragStartRef.current.initialY + dy, maxY)),
    });
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    if (isDragging) {
      setIsDragging(false);
      try {
        (e.target as HTMLElement).releasePointerCapture(e.pointerId);
      } catch {
        // ignore
      }
    }
  };

  if (!visible) return null;

  // Thermal badge styling
  const getTempColor = (temp: TelemetryData['thermalState']) => {
    switch (temp) {
      case 'Warm':
        return 'text-amber-400';
      case 'Hot':
        return 'text-orange-500';
      case 'Critical!':
        return 'text-red-500 font-black animate-pulse';
      default:
        return 'text-emerald-400';
    }
  };

  const bgColorWithOpacity = hexToRgba(settings.bgColor, settings.opacity);
  const scale = settings.scale || 1.0;

  return (
    <div
      style={{
        transform: `translate3d(${position.x}px, ${position.y}px, 0) scale(${scale})`,
        transformOrigin: 'top left',
        width: `${pipWidth}px`,
        height: `${pipHeight}px`,
        backgroundColor: bgColorWithOpacity,
        borderColor: isDragging ? settings.accentColor : 'rgba(255, 255, 255, 0.3)',
      }}
      className={`fixed top-0 left-0 z-50 rounded-[14px] backdrop-blur-md border shadow-2xl cursor-grab active:cursor-grabbing select-none transition-shadow ${
        isDragging ? 'ring-2' : 'hover:border-white/50'
      }`}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
    >
      {/* Subtle indicator bar */}
      <div className="absolute top-1.5 left-1/2 -translate-x-1/2 w-7 h-1 rounded-full bg-white/20 pointer-events-none" />

      {/* Action button to open Fullscreen Dashboard */}
      <button
        onClick={(e) => {
          e.stopPropagation();
          onOpenDashboard();
        }}
        title="Open Fullscreen Performance Dashboard (Settings)"
        className="absolute top-1.5 right-1.5 p-1 rounded-md text-white/50 hover:text-white hover:bg-white/10 transition-colors"
      >
        <Maximize2 className="w-3 h-3" />
      </button>

      {/* Main Info Display */}
      <div className="flex flex-col items-center justify-center h-full px-2 pt-2 text-[11px] font-semibold leading-snug tracking-tight text-white font-mono pointer-events-none space-y-0.5">
        {settings.showCpu && (
          <div className="flex items-center gap-1.5">
            <span className="text-white/70">CPU:</span>
            <span style={{ color: settings.accentColor }} className="font-bold">
              {formatDec(telemetry.cpuUsage)}%
            </span>
          </div>
        )}
        {settings.showRam && (
          <div className="flex items-center gap-1.5">
            <span className="text-white/70">RAM:</span>
            <span className="font-bold text-purple-300">{formatDec(telemetry.ramMB)} MB</span>
          </div>
        )}
        {settings.showThermal && (
          <div className="flex items-center gap-1.5">
            <span className="text-white/70">Temp:</span>
            <span className={`font-bold ${getTempColor(telemetry.thermalState)}`}>
              {telemetry.thermalState}
            </span>
          </div>
        )}
        {settings.showFps && (
          <div className="flex items-center gap-1.5">
            <span className="text-white/70">FPS:</span>
            <span className="font-bold text-emerald-400">{formatDec(telemetry.fps)}</span>
          </div>
        )}
        {settings.showModel && (
          <div className="flex items-center gap-1.5">
            <span className="text-white/70">Dev:</span>
            <span className="font-bold text-cyan-200 truncate max-w-[85px]">
              {telemetry.deviceModel.split(' ')[0]}
            </span>
          </div>
        )}

        {activeMetricsCount === 0 && (
          <div className="text-[10px] text-neutral-400 italic">No metrics selected</div>
        )}
      </div>
    </div>
  );
};
