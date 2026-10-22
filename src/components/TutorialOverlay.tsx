import React, { useState, useEffect } from 'react';
import { triggerHaptic } from '../utils/telemetry.ts';
import { Sparkles, Hand, CheckCircle } from 'lucide-react';

interface TutorialOverlayProps {
  isOpen: boolean;
  onCompleted: () => void;
  onSimulateFourFingerTap: () => void;
  onSimulateFourFingerHold: () => void;
}

interface TouchPoint {
  id: number;
  x: number;
  y: number;
}

export const TutorialOverlay: React.FC<TutorialOverlayProps> = ({
  isOpen,
  onCompleted,
  onSimulateFourFingerTap,
  onSimulateFourFingerHold,
}) => {
  const [touches, setTouches] = useState<TouchPoint[]>([]);
  const [isTriggered, setIsTriggered] = useState(false);

  useEffect(() => {
    if (!isOpen) {
      setIsTriggered(false);
      setTouches([]);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const isFourFingers = touches.length >= 4 || isTriggered;

  const handleTouchStart = (e: React.TouchEvent) => {
    updateTouches(e);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    updateTouches(e);
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    const updated: TouchPoint[] = [];
    for (let i = 0; i < e.touches.length; i++) {
      const t = e.touches[i];
      updated.push({ id: t.identifier, x: t.clientX, y: t.clientY });
    }
    setTouches(updated);
  };

  const updateTouches = (e: React.TouchEvent) => {
    const currentTouches: TouchPoint[] = [];
    for (let i = 0; i < e.touches.length; i++) {
      const t = e.touches[i];
      currentTouches.push({ id: t.identifier, x: t.clientX, y: t.clientY });
    }
    setTouches(currentTouches);

    // Auto trigger when 4 fingers touched
    if (currentTouches.length >= 4 && !isTriggered) {
      triggerSuccess();
    }
  };

  const triggerSuccess = () => {
    setIsTriggered(true);
    triggerHaptic('medium');
    setTimeout(() => {
      onCompleted();
    }, 1000);
  };

  const handleSimulateGesture = () => {
    // Generate 4 mock touch points
    const w = window.innerWidth;
    const h = window.innerHeight;
    setTouches([
      { id: 1, x: w * 0.35, y: h * 0.4 },
      { id: 2, x: w * 0.45, y: h * 0.38 },
      { id: 3, x: w * 0.55, y: h * 0.4 },
      { id: 4, x: w * 0.65, y: h * 0.44 },
    ]);
    triggerSuccess();
  };

  return (
    <div
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
      className="fixed inset-0 z-[60] bg-black/85 backdrop-blur-md flex flex-col items-center justify-between p-6 select-none touch-none animate-in fade-in duration-300"
    >
      {/* Top Banner matching _headerInstructionLabel in main.m */}
      <div className="w-full max-w-md pt-4 sm:pt-8 flex flex-col items-center space-y-3 pointer-events-auto">
        <div
          className={`w-full py-2.5 px-4 rounded-full text-center text-[13px] font-bold border transition-all duration-300 shadow-xl ${
            isTriggered
              ? 'bg-emerald-500/30 text-emerald-300 border-emerald-400 scale-105'
              : 'bg-white/12 text-white border-white/20'
          }`}
        >
          {isTriggered
            ? '✓ Gesture detected! Launching...'
            : 'Place 4 fingers: Tap = PiP | Hold = Menu'}
        </div>

        <p className="text-[12px] font-semibold text-cyan-400 text-center">
          {isTriggered
            ? 'Entering LiveContainer monitor mode'
            : 'Touch screen with 4 fingers simultaneously, or click buttons below'}
        </p>

        {/* Skip button matching _skipButton */}
        <button
          onClick={onCompleted}
          className="px-6 py-1.5 rounded-full bg-white/15 hover:bg-white/25 active:bg-white/35 text-white text-[13px] font-bold border border-white/30 transition-all shadow-md active:scale-95"
        >
          Skip Tutorial
        </button>
      </div>

      {/* Center Interactive Playground */}
      <div className="flex-1 flex flex-col items-center justify-center text-center px-4 max-w-sm pointer-events-none">
        <div className="relative mb-6">
          <div className="w-24 h-24 rounded-full bg-cyan-500/10 border border-cyan-400/20 flex items-center justify-center animate-pulse">
            <Hand className="w-12 h-12 text-cyan-400 opacity-90" />
          </div>
          <div className="absolute -top-1 -right-1 bg-cyan-500 text-black text-[11px] font-black px-2 py-0.5 rounded-full">
            4x
          </div>
        </div>

        <h3 className="text-lg font-bold text-white mb-2">
          Multi-Touch Gesture Engine
        </h3>
        <p className="text-xs text-neutral-400 leading-relaxed">
          In iOS, this tweak hooks into low-level window touch events to toggle
          the PiP overlay or open the diagnostic suite without interfering with
          host apps.
        </p>
      </div>

      {/* Bottom Desktop / One-Click Helpers */}
      <div className="w-full max-w-md pb-4 sm:pb-6 flex flex-col gap-2 pointer-events-auto">
        <div className="text-[11px] font-semibold text-neutral-400 uppercase tracking-wider text-center mb-1">
          Quick Simulation Controls
        </div>
        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={handleSimulateGesture}
            className="py-2.5 px-3 rounded-xl bg-cyan-600/30 hover:bg-cyan-600/40 border border-cyan-400/30 text-cyan-200 text-xs font-semibold flex items-center justify-center gap-1.5 transition-all active:scale-95"
          >
            <Sparkles className="w-3.5 h-3.5" />
            <span>Test 4-Finger Touch</span>
          </button>
          <button
            onClick={() => {
              onCompleted();
              onSimulateFourFingerTap();
            }}
            className="py-2.5 px-3 rounded-xl bg-white/10 hover:bg-white/20 border border-white/20 text-white text-xs font-semibold flex items-center justify-center gap-1.5 transition-all active:scale-95"
          >
            <CheckCircle className="w-3.5 h-3.5 text-purple-400" />
            <span>Toggle PiP Directly</span>
          </button>
        </div>
      </div>

      {/* Render Real-Time Finger Touch Dots matching renderTouchesFromEvent in main.m */}
      {touches.map((touch) => (
        <div
          key={touch.id}
          style={{
            left: `${touch.x}px`,
            top: `${touch.y}px`,
            transform: 'translate(-50%, -50%)',
          }}
          className={`fixed pointer-events-none w-12 h-12 rounded-full border-[2.5px] border-white shadow-lg transition-transform duration-75 flex items-center justify-center text-[11px] font-bold text-white ${
            isFourFingers
              ? 'bg-emerald-500 shadow-emerald-500/50 scale-110'
              : 'bg-cyan-500/80 shadow-cyan-500/40'
          }`}
        >
          {touch.id}
        </div>
      ))}
    </div>
  );
};
