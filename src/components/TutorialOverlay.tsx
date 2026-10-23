import React, { useState, useEffect, useRef } from 'react';
import { triggerHaptic } from '../utils/telemetry.ts';
import {
  Hand,
  CheckCircle2,
  Sliders,
  ChevronRight,
  ChevronLeft,
  Move,
  Clock,
  Sparkles,
  Smartphone,
  Eye,
} from 'lucide-react';

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
  const [currentStep, setCurrentStep] = useState<number>(1);
  const [touches, setTouches] = useState<TouchPoint[]>([]);
  const [isTriggered, setIsTriggered] = useState(false);
  const [holdProgress, setHoldProgress] = useState<number>(0);
  const holdTimerRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (!isOpen) {
      setCurrentStep(1);
      setIsTriggered(false);
      setTouches([]);
      setHoldProgress(0);
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

    if (currentTouches.length >= 4 && !isTriggered) {
      triggerSuccess();
    }
  };

  const triggerSuccess = () => {
    setIsTriggered(true);
    triggerHaptic('medium');
  };

  const simulateFourFingerTouch = () => {
    const w = window.innerWidth;
    const h = window.innerHeight;
    setTouches([
      { id: 1, x: w * 0.35, y: h * 0.42 },
      { id: 2, x: w * 0.45, y: h * 0.39 },
      { id: 3, x: w * 0.55, y: h * 0.41 },
      { id: 4, x: w * 0.65, y: h * 0.45 },
    ]);
    triggerSuccess();
  };

  // Hold 2s simulator
  const handleHoldStart = () => {
    setHoldProgress(0);
    const start = Date.now();
    holdTimerRef.current = setInterval(() => {
      const elapsed = Date.now() - start;
      const pct = Math.min(100, Math.round((elapsed / 2000) * 100));
      setHoldProgress(pct);
      if (pct >= 100) {
        clearInterval(holdTimerRef.current!);
        triggerHaptic('heavy');
        onCompleted();
        onSimulateFourFingerHold();
      }
    }, 50);
  };

  const handleHoldEnd = () => {
    if (holdTimerRef.current) {
      clearInterval(holdTimerRef.current);
    }
    setHoldProgress(0);
  };

  return (
    <div
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
      className="fixed inset-0 z-[60] bg-black/90 backdrop-blur-xl flex flex-col items-center justify-between p-4 sm:p-6 select-none animate-in fade-in duration-300"
    >
      {/* Top Bar with Step Indicators */}
      <div className="w-full max-w-md pt-3 flex items-center justify-between pointer-events-auto">
        <div className="flex items-center gap-2">
          {[1, 2, 3].map((step) => (
            <button
              key={step}
              onClick={() => setCurrentStep(step)}
              className={`h-1.5 rounded-full transition-all ${
                currentStep === step
                  ? 'w-8 bg-cyan-400'
                  : currentStep > step
                  ? 'w-4 bg-emerald-400'
                  : 'w-4 bg-white/20'
              }`}
            />
          ))}
          <span className="text-[11px] font-mono text-neutral-400 ml-1">
            Krok {currentStep} z 3
          </span>
        </div>

        <button
          onClick={onCompleted}
          className="px-3.5 py-1 rounded-full bg-white/10 hover:bg-white/20 active:bg-white/30 text-white text-xs font-semibold border border-white/20 transition-all"
        >
          Pomiń (Skip)
        </button>
      </div>

      {/* Main Content Area based on current step */}
      <div className="w-full max-w-md flex-1 flex flex-col items-center justify-center py-4 pointer-events-auto">
        {currentStep === 1 && (
          <div className="w-full flex flex-col items-center text-center space-y-4 animate-in fade-in slide-in-from-right-4 duration-200">
            {/* Visual Animated Hand Icon */}
            <div className="relative">
              <div className="w-24 h-24 rounded-3xl bg-cyan-500/15 border-2 border-cyan-400/30 flex items-center justify-center shadow-xl shadow-cyan-500/10">
                <Hand className="w-12 h-12 text-cyan-300 animate-bounce" />
              </div>
              <div className="absolute -top-2 -right-2 bg-gradient-to-r from-cyan-500 to-blue-500 text-black text-xs font-black px-2.5 py-0.5 rounded-full shadow">
                4 PALCE
              </div>
            </div>

            <div className="space-y-1.5">
              <h3 className="text-xl font-bold text-white tracking-tight">
                Interaktywny Gest 4 Palców
              </h3>
              <p className="text-xs text-neutral-300 leading-relaxed max-w-sm">
                Aplikacja w tle używa 1, 2 lub 3 palców do sterowania (np. w grach
                w LiveContainer). Dotknięcie <strong className="text-cyan-400">4 palcami</strong> nigdy
                nie koliduje z grą i natychmiast wywołuje nakładkę diagnostyczną!
              </p>
            </div>

            {/* Live Touch Counter Indicator */}
            <div
              className={`w-full py-3 px-4 rounded-2xl border transition-all ${
                isFourFingers
                  ? 'bg-emerald-500/20 border-emerald-400/50 text-emerald-300'
                  : 'bg-white/5 border-white/10 text-neutral-300'
              }`}
            >
              <div className="flex items-center justify-between text-xs font-semibold mb-1">
                <span>Wykryte punkty dotyku na ekranie:</span>
                <span className="font-mono font-bold text-sm">
                  {touches.length} / 4
                </span>
              </div>
              <div className="w-full h-2 bg-black/40 rounded-full overflow-hidden">
                <div
                  style={{ width: `${Math.min(100, (touches.length / 4) * 100)}%` }}
                  className={`h-full transition-all duration-150 ${
                    isFourFingers ? 'bg-emerald-400' : 'bg-cyan-400'
                  }`}
                />
              </div>
            </div>

            {/* Test touch button for single mouse/touchpad users */}
            <button
              onClick={simulateFourFingerTouch}
              className="py-2.5 px-4 rounded-xl bg-cyan-500/20 hover:bg-cyan-500/30 border border-cyan-400/40 text-cyan-200 text-xs font-semibold flex items-center gap-2 transition-all active:scale-95"
            >
              <Sparkles className="w-4 h-4 text-cyan-300" />
              <span>Przetestuj dotyk 4 palcami (Symulacja)</span>
            </button>
          </div>
        )}

        {currentStep === 2 && (
          <div className="w-full flex flex-col items-center text-center space-y-4 animate-in fade-in slide-in-from-right-4 duration-200">
            <div className="flex items-center justify-center gap-3">
              <div className="p-3 rounded-2xl bg-cyan-500/20 border border-cyan-400/30 text-cyan-300">
                <Hand className="w-8 h-8" />
              </div>
              <span className="text-xl font-bold text-neutral-500">+</span>
              <div className="p-3 rounded-2xl bg-purple-500/20 border border-purple-400/30 text-purple-300">
                <Clock className="w-8 h-8" />
              </div>
            </div>

            <div className="space-y-1">
              <h3 className="text-lg font-bold text-white tracking-tight">
                Stuknięcie (PiP) vs Przytrzymanie 2s (Menu)
              </h3>
              <p className="text-xs text-neutral-300 max-w-sm">
                Masz pełną kontrolę nad nakładką dwoma intuicyjnymi gestami:
              </p>
            </div>

            {/* Gesture Action Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 w-full text-left">
              <div className="p-3.5 rounded-2xl bg-cyan-950/40 border border-cyan-500/30 space-y-1">
                <div className="text-xs font-bold text-cyan-300 flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-cyan-400 animate-ping" />
                  Stuknięcie 4 palcami (Tap)
                </div>
                <p className="text-[11px] text-neutral-300">
                  Szybkie pojedyncze stuknięcie natychmiast ukrywa lub pokazuje
                  pływający widżet PiP z procesorem i pamięcią RAM.
                </p>
              </div>

              <div className="p-3.5 rounded-2xl bg-purple-950/40 border border-purple-500/30 space-y-1">
                <div className="text-xs font-bold text-purple-300 flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-purple-400 animate-pulse" />
                  Przytrzymanie 2s (Hold)
                </div>
                <p className="text-[11px] text-neutral-300">
                  Przytrzymaj 4 palce przez 2 sekundy, aby otworzyć pełne
                  Sekretne Menu: ustawienia kolorów, OOM test i specyfikację.
                </p>
              </div>
            </div>

            {/* Interactive Hold Practice Button */}
            <div className="w-full flex flex-col items-center pt-1">
              <button
                onMouseDown={handleHoldStart}
                onMouseUp={handleHoldEnd}
                onMouseLeave={handleHoldEnd}
                onTouchStart={handleHoldStart}
                onTouchEnd={handleHoldEnd}
                className="w-full py-3 px-4 rounded-xl bg-purple-600/30 hover:bg-purple-600/40 border border-purple-400/40 text-purple-200 text-xs font-bold transition-all relative overflow-hidden select-none active:scale-[0.99]"
              >
                <div
                  style={{ width: `${holdProgress}%` }}
                  className="absolute left-0 top-0 bottom-0 bg-purple-600/60 transition-all duration-75"
                />
                <span className="relative z-10 flex items-center justify-center gap-2">
                  <Clock className="w-4 h-4" />
                  {holdProgress > 0
                    ? `Przytrzymano... ${holdProgress}%`
                    : 'Naciśnij i przytrzymaj tutaj przez 2 sekundy'}
                </span>
              </button>
              <span className="text-[10px] text-neutral-400 mt-1">
                Test przytrzymania otwiera bezpośrednio sekretne menu
              </span>
            </div>
          </div>
        )}

        {currentStep === 3 && (
          <div className="w-full flex flex-col items-center text-center space-y-4 animate-in fade-in slide-in-from-right-4 duration-200">
            <div className="p-3.5 rounded-3xl bg-blue-500/20 border-2 border-blue-400/30 text-blue-300">
              <Sliders className="w-10 h-10" />
            </div>

            <div className="space-y-1">
              <h3 className="text-lg font-bold text-white tracking-tight">
                Pełna Personalizacja i Swobodne Przeciąganie
              </h3>
              <p className="text-xs text-neutral-300 max-w-sm">
                W nowej wersji masz pełną kontrolę nad wyglądem okienka PiP:
              </p>
            </div>

            <div className="w-full space-y-2 text-left text-xs">
              <div className="p-3 rounded-xl bg-white/[0.05] border border-white/10 flex items-start gap-2.5">
                <Move className="w-4 h-4 text-cyan-400 shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-white">Swobodne przesuwanie</div>
                  <div className="text-[11px] text-neutral-400">
                    Chwyć okienko palcem lub myszą i przesuń w dowolny róg ekranu.
                  </div>
                </div>
              </div>

              <div className="p-3 rounded-xl bg-white/[0.05] border border-white/10 flex items-start gap-2.5">
                <Eye className="w-4 h-4 text-purple-400 shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-white">Suwak przeźroczystości</div>
                  <div className="text-[11px] text-neutral-400">
                    Dopasuj przezroczystość od 20% do 100%, aby nie zasłaniać gry.
                  </div>
                </div>
              </div>

              <div className="p-3 rounded-xl bg-white/[0.05] border border-white/10 flex items-start gap-2.5">
                <Sliders className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-white">Dowolny kolor i wybrane dane</div>
                  <div className="text-[11px] text-neutral-400">
                    Wybierz własny kolor z palety RGB oraz włącz lub wyłącz CPU, RAM,
                    temperaturę czy licznik FPS.
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Bottom Step Navigation Controls */}
      <div className="w-full max-w-md pt-3 border-t border-white/10 flex items-center justify-between gap-3 pointer-events-auto">
        {currentStep > 1 ? (
          <button
            onClick={() => setCurrentStep(currentStep - 1)}
            className="py-2.5 px-4 rounded-xl bg-white/10 hover:bg-white/20 text-neutral-300 text-xs font-bold flex items-center gap-1.5 transition-all"
          >
            <ChevronLeft className="w-4 h-4" />
            <span>Wstecz</span>
          </button>
        ) : (
          <div />
        )}

        {currentStep < 3 ? (
          <button
            onClick={() => setCurrentStep(currentStep + 1)}
            className="py-2.5 px-5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold flex items-center gap-1.5 shadow-lg transition-all active:scale-95"
          >
            <span>Dalej</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        ) : (
          <button
            onClick={() => {
              triggerHaptic('medium');
              onCompleted();
              onSimulateFourFingerTap();
            }}
            className="py-2.5 px-5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold flex items-center gap-1.5 shadow-lg shadow-emerald-950/40 transition-all active:scale-95"
          >
            <CheckCircle2 className="w-4 h-4" />
            <span>Zakończ i uruchom PiP</span>
          </button>
        )}
      </div>

      {/* Render Real-Time Finger Touch Dots */}
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
              ? 'bg-emerald-500 shadow-emerald-500/50 scale-110 animate-ping'
              : 'bg-cyan-500/80 shadow-cyan-500/40'
          }`}
        >
          {touch.id}
        </div>
      ))}
    </div>
  );
};
