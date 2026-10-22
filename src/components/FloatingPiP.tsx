import React, { useState, useRef, useEffect } from 'react';
import { TelemetryData } from '../types.ts';
import { formatDec } from '../utils/telemetry.ts';
import { Maximize2, Move } from 'lucide-react';

interface FloatingPiPProps {
  telemetry: TelemetryData;
  visible: boolean;
  onOpenDashboard: () => void;
  onToggleVisible: () => void;
  containerRef?: React.RefObject<HTMLDivElement | null>;
}

export const FloatingPiP: React.FC<FloatingPiPProps> = ({
  telemetry,
  visible,
  onOpenDashboard,
  onToggleVisible,
  containerRef,
}) => {
  // Default position: top centered (similar to main.m: center = (screenWidth / 2, 90))
  const [position, setPosition] = useState<{ x: number; y: number }>({ x: 20, y: 75 });
  const [isDragging, setIsDragging] = useState(false);
  const dragStartRef = useRef<{ mouseX: number; mouseY: number; initialX: number; initialY: number }>({
    mouseX: 0,
    mouseY: 0,
    initialX: 0,
    initialY: 0,
  });

  // Keep within bounds on resize
  useEffect(() => {
    const handleResize = () => {
      const parent = containerRef?.current || document.body;
      const bounds = parent.getBoundingClientRect();
      setPosition((prev) => ({
        x: Math.max(10, Math.min(prev.x, bounds.width - 150)),
        y: Math.max(10, Math.min(prev.y, bounds.height - 80)),
      }));
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [containerRef]);

  const handlePointerDown = (e: React.PointerEvent) => {
    // Only drag with primary click/touch
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
    const maxX = Math.max(10, bounds.width - 145);
    const maxY = Math.max(10, bounds.height - 75);

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

  return (
    <div
      style={{
        transform: `translate3d(${position.x}px, ${position.y}px, 0)`,
        width: '142px',
        height: '72px',
      }}
      className={`fixed top-0 left-0 z-50 rounded-[14px] bg-black/85 backdrop-blur-md border border-white/30 shadow-2xl cursor-grab active:cursor-grabbing select-none transition-shadow ${
        isDragging ? 'shadow-cyan-500/30 ring-2 ring-cyan-400/50' : 'hover:border-white/50'
      }`}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
    >
      {/* Subtle indicator bar */}
      <div className="absolute top-1.5 left-1/2 -translate-x-1/2 w-7 h-1 rounded-full bg-white/20 pointer-events-none" />

      {/* Action buttons (top right & left) */}
      <button
        onClick={(e) => {
          e.stopPropagation();
          onOpenDashboard();
        }}
        title="Open Fullscreen Performance Dashboard"
        className="absolute top-1.5 right-1.5 p-1 rounded-md text-white/50 hover:text-white hover:bg-white/10 transition-colors"
      >
        <Maximize2 className="w-3 h-3" />
      </button>

      {/* Main Info Display matching main.m text format */}
      <div className="flex flex-col items-center justify-center h-full px-2 pt-2 text-[11.5px] font-semibold leading-snug tracking-tight text-white font-mono pointer-events-none">
        <div className="flex items-center gap-1.5">
          <span className="text-white/70">CPU:</span>
          <span className="font-bold text-cyan-300">{formatDec(telemetry.cpuUsage)}%</span>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="text-white/70">RAM:</span>
          <span className="font-bold text-purple-300">{formatDec(telemetry.ramMB)} MB</span>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="text-white/70">Temp:</span>
          <span className={`font-bold ${getTempColor(telemetry.thermalState)}`}>
            {telemetry.thermalState}
          </span>
        </div>
      </div>
    </div>
  );
};
