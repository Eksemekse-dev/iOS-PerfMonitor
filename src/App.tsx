import React, { useState, useEffect, useRef } from 'react';
import { TelemetryData, StressTestState, PipSettings } from './types.ts';
import {
  getInitialDeviceInfo,
  calculateThermalState,
  triggerHaptic,
  formatDec,
} from './utils/telemetry.ts';
import { FloatingPiP } from './components/FloatingPiP.tsx';
import { DashboardModal } from './components/DashboardModal.tsx';
import { TutorialOverlay } from './components/TutorialOverlay.tsx';
import { OOMAlertModal } from './components/OOMAlertModal.tsx';
import { SimulatedHostApp } from './components/SimulatedHostApp.tsx';
import { SetupGuideModal } from './components/SetupGuideModal.tsx';
import {
  Activity,
  Layers,
  HelpCircle,
  RotateCw,
  Maximize,
  Minimize,
  Wifi,
  Battery,
  Flame,
  CheckCircle2,
  Play,
  RotateCcw,
} from 'lucide-react';

export default function App() {
  const containerRef = useRef<HTMLDivElement | null>(null);

  // Device telemetry state
  const [telemetry, setTelemetry] = useState<TelemetryData>(() => ({
    cpuUsage: 12.4,
    gpuUsage: 24.5,
    ramMB: 48.6,
    thermalState: 'Normal',
    fps: 60,
    deviceModel: 'iPhone15,2',
    iosVersion: '17.5.1',
    bundleId: 'com.livecontainer.iosperfmonitor',
    debuggerAttached: false,
    totalDeviceRamMB: 6144,
    ...getInitialDeviceInfo(),
  }));

  // Workload simulator
  const [cpuLoadFactor, setCpuLoadFactor] = useState<number>(1);
  const [currentFps, setCurrentFps] = useState<number>(60);

  // Overlay window visibility states matching main.m
  const [isPipVisible, setIsPipVisible] = useState<boolean>(true);
  const [isDashboardOpen, setIsDashboardOpen] = useState<boolean>(false);
  const [isTutorialOpen, setIsTutorialOpen] = useState<boolean>(false);
  const [isSetupGuideOpen, setIsSetupGuideOpen] = useState<boolean>(false);

  // PiP Customization Settings with localStorage persistence
  const [pipSettings, setPipSettings] = useState<PipSettings>(() => {
    try {
      const saved = localStorage.getItem('perf_monitor_pip_settings');
      if (saved) {
        return JSON.parse(saved);
      }
    } catch {
      // ignore
    }
    return {
      opacity: 0.85,
      scale: 1.0,
      bgColor: '#000000',
      accentColor: '#38bdf8',
      showCpu: true,
      showGpu: true,
      showRam: true,
      showThermal: true,
      showFps: false,
      showModel: false,
    };
  });

  const handleUpdateSettings = (newSettings: PipSettings) => {
    setPipSettings(newSettings);
    try {
      localStorage.setItem('perf_monitor_pip_settings', JSON.stringify(newSettings));
    } catch {
      // ignore
    }
  };

  // Alerts
  const [alertState, setAlertState] = useState<{
    isOpen: boolean;
    type: 'confirm' | 'result';
    allocatedMB?: number;
  }>({
    isOpen: false,
    type: 'confirm',
  });

  // RAM Stress test state
  const [stressTest, setStressTest] = useState<StressTestState>({
    status: 'idle',
    allocatedMB: 0,
  });

  // Presentation view: 'phone' (iPhone 15 Pro frame) or 'full' (fullscreen overlay)
  const [viewMode, setViewMode] = useState<'phone' | 'full'>('phone');

  // Clock for iOS status bar
  const [currentTime, setCurrentTime] = useState<string>('9:41');

  // Check tutorial completion and prior crash results on startup
  useEffect(() => {
    // 1. Check previous crash or test result matching checkPreviousCrashOrTestResult in main.m
    try {
      const savedCrash = localStorage.getItem('perf_monitor_ram_test_state');
      if (savedCrash) {
        const parsed = JSON.parse(savedCrash);
        if (parsed.status === 'running' || parsed.status === 'crashed') {
          localStorage.removeItem('perf_monitor_ram_test_state');
          setAlertState({
            isOpen: true,
            type: 'result',
            allocatedMB: parsed.allocatedMB || 2450,
          });
        }
      }
    } catch {
      // ignore
    }

    // 2. Check tutorial completion flag matching hasCompletedTutorial in main.m
    const tutorialDone = localStorage.getItem('perf_monitor_tutorial_v7');
    if (!tutorialDone) {
      // delay opening tutorial slightly for smooth mount
      const t = setTimeout(() => {
        setIsTutorialOpen(true);
      }, 600);
      return () => clearTimeout(t);
    }
  }, []);

  // Update real-time clock
  useEffect(() => {
    const updateClock = () => {
      const now = new Date();
      const hours = now.getHours();
      const minutes = now.getMinutes().toString().padStart(2, '0');
      setCurrentTime(`${hours}:${minutes}`);
    };
    updateClock();
    const interval = setInterval(updateClock, 10000);
    return () => clearInterval(interval);
  }, []);

  // Periodic Telemetry Timer matching [NSTimer scheduledTimerWithTimeInterval:1.0 ...]
  useEffect(() => {
    const timer = setInterval(() => {
      setTelemetry((prev) => {
        // Base CPU from simulated particle physics workload + natural jitter
        const baseCpu = 8 * cpuLoadFactor + (stressTest.status === 'running' ? 35 : 0);
        const jitter = (Math.random() - 0.5) * 4;
        const newCpu = Math.max(2.1, Math.min(99.4, baseCpu + jitter));

        // Simulated GPU activity based on particles & rendering
        const baseGpu = 12 * cpuLoadFactor + (stressTest.status === 'running' ? 18 : 0);
        const gpuJitter = (Math.random() - 0.5) * 5;
        const newGpu = Math.max(1.5, Math.min(98.5, baseGpu + gpuJitter));

        // Base RAM ~48MB + allocated stress test RAM + minor fluctuations
        const baseRam = 48.2 + (stressTest.allocatedMB || 0);
        const ramJitter = (Math.random() - 0.5) * 1.5;
        const newRam = Math.max(30, baseRam + ramJitter);

        const newThermal = calculateThermalState(newCpu, newRam);

        return {
          ...prev,
          cpuUsage: newCpu,
          gpuUsage: newGpu,
          ramMB: newRam,
          thermalState: newThermal,
          fps: currentFps,
        };
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [cpuLoadFactor, stressTest.status, stressTest.allocatedMB, currentFps]);

  // Execute RAM Stress Test loop matching runRamStressTest in main.m
  useEffect(() => {
    if (stressTest.status !== 'running') return;

    const chunkSizeMB = 50;
    const interval = setInterval(() => {
      setStressTest((prev) => {
        const nextAlloc = prev.allocatedMB + chunkSizeMB;

        // Persist progress to localStorage matching writeToFile
        localStorage.setItem(
          'perf_monitor_ram_test_state',
          JSON.stringify({ status: 'running', allocatedMB: nextAlloc }),
        );

        // Crash trigger threshold (emulating iOS Jetsam / LiveContainer OOM limit, typically ~2400-3000MB)
        if (nextAlloc >= 2500) {
          clearInterval(interval);
          handleOomCrash(nextAlloc);
          return { status: 'crashed', allocatedMB: nextAlloc };
        }

        return { ...prev, allocatedMB: nextAlloc };
      });
    }, 80);

    return () => clearInterval(interval);
  }, [stressTest.status]);

  const handleOomCrash = (maxMB: number) => {
    triggerHaptic('heavy');
    // Save crash result
    localStorage.setItem(
      'perf_monitor_ram_test_state',
      JSON.stringify({ status: 'crashed', allocatedMB: maxMB }),
    );

    // Simulate momentary iOS crash freeze & recovery
    setTimeout(() => {
      setStressTest({ status: 'idle', allocatedMB: 0 });
      setAlertState({
        isOpen: true,
        type: 'result',
        allocatedMB: maxMB,
      });
    }, 400);
  };

  const handleStartStressTestConfirmed = () => {
    setAlertState({ isOpen: false, type: 'confirm' });
    setIsDashboardOpen(false);
    setStressTest({ status: 'running', allocatedMB: 0 });
  };

  const handleTutorialCompleted = () => {
    localStorage.setItem('perf_monitor_tutorial_v7', 'completed');
    setIsTutorialOpen(false);
  };

  const handleResetTutorial = () => {
    localStorage.removeItem('perf_monitor_tutorial_v7');
    setIsTutorialOpen(true);
  };

  return (
    <div
      ref={containerRef}
      className="relative w-screen h-screen overflow-hidden bg-neutral-950 text-white flex flex-col font-sans select-none"
    >
      {/* Top Application Control Bar */}
      <header className="h-12 bg-[#12131a] border-b border-white/10 px-4 flex items-center justify-between shrink-0 z-40">
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-blue-600/30 border border-blue-500/40 text-blue-400 flex items-center justify-center">
              <Activity className="w-4 h-4" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-white tracking-tight flex items-center gap-2">
                <span>iOS-PerfMonitor</span>
                <span className="text-[10px] px-1.5 py-0.5 rounded bg-cyan-500/20 text-cyan-300 font-mono font-semibold">
                  LiveContainer Overlay
                </span>
              </h1>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-2">
          {/* 4-Finger Tap Simulation Button */}
          <button
            onClick={() => {
              triggerHaptic('light');
              setIsPipVisible(!isPipVisible);
            }}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 border transition-all ${
              isPipVisible
                ? 'bg-cyan-500/20 border-cyan-400/40 text-cyan-200'
                : 'bg-white/5 border-white/10 text-neutral-400 hover:text-white'
            }`}
            title="Simulate 4-Finger Tap (Toggle PiP)"
          >
            <span>{isPipVisible ? 'Hide PiP' : 'Show PiP'}</span>
            <span className="text-[10px] text-white/50">(4-Tap)</span>
          </button>

          {/* 4-Finger Long Press Simulation Button */}
          <button
            onClick={() => {
              triggerHaptic('medium');
              setIsDashboardOpen(true);
            }}
            className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white flex items-center gap-1.5 shadow-md transition-all active:scale-95"
            title="Simulate 4-Finger Long Press 2s (Open Dashboard)"
          >
            <Activity className="w-3.5 h-3.5" />
            <span>Dashboard</span>
            <span className="text-[10px] text-white/70">(4-Hold)</span>
          </button>

          {/* Quick Stress Test trigger */}
          {stressTest.status === 'running' ? (
            <button
              onClick={() => setStressTest({ status: 'idle', allocatedMB: 0 })}
              className="px-3 py-1.5 rounded-lg text-xs font-bold bg-amber-600 hover:bg-amber-500 text-white flex items-center gap-1 animate-pulse"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              <span>Stop Test ({stressTest.allocatedMB}MB)</span>
            </button>
          ) : (
            <button
              onClick={() => setAlertState({ isOpen: true, type: 'confirm' })}
              className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-600/20 hover:bg-red-600/30 border border-red-500/40 text-red-300 flex items-center gap-1 transition-all"
            >
              <Flame className="w-3.5 h-3.5 text-red-400" />
              <span className="hidden sm:inline">Stress Test</span>
            </button>
          )}

          <div className="h-5 w-px bg-white/15 mx-1" />

          {/* View Mode Toggle */}
          <button
            onClick={() => setViewMode(viewMode === 'phone' ? 'full' : 'phone')}
            className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-neutral-300 hover:text-white transition-colors"
            title={viewMode === 'phone' ? 'Switch to Fullscreen View' : 'Switch to iPhone Frame View'}
          >
            {viewMode === 'phone' ? (
              <Maximize className="w-4 h-4" />
            ) : (
              <Minimize className="w-4 h-4" />
            )}
          </button>

          {/* Setup Guide */}
          <button
            onClick={() => setIsSetupGuideOpen(true)}
            className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-neutral-300 hover:text-white transition-colors"
            title="Setup & Architecture Guide"
          >
            <HelpCircle className="w-4 h-4" />
          </button>

          {/* Replay Tutorial */}
          <button
            onClick={handleResetTutorial}
            className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-neutral-300 hover:text-white transition-colors"
            title="Replay 4-Finger Touch Tutorial"
          >
            <RotateCw className="w-4 h-4" />
          </button>
        </div>
      </header>

      {/* Main Workspace Body */}
      <main className="flex-1 relative flex items-center justify-center p-0 sm:p-4 bg-radial from-neutral-900 to-black overflow-hidden">
        {viewMode === 'phone' ? (
          /* Realistic iPhone 15 Pro Bezel Canvas */
          <div className="relative w-full max-w-[390px] h-full max-h-[820px] rounded-none sm:rounded-[50px] border-0 sm:border-[10px] border-[#2d2d34] shadow-[0_0_60px_rgba(0,0,0,0.8)] bg-black overflow-hidden flex flex-col ring-1 ring-white/10">
            {/* Dynamic Island / Notch */}
            <div className="absolute top-2.5 left-1/2 -translate-x-1/2 w-28 h-7 bg-black rounded-full z-50 flex items-center justify-between px-3 border border-white/10 shadow-lg pointer-events-none">
              <div className="w-2.5 h-2.5 rounded-full bg-[#111] ring-1 ring-white/10" />
              <div className="w-2 h-2 rounded-full bg-emerald-500/80 animate-pulse" />
            </div>

            {/* iOS Status Bar */}
            <div className="h-11 px-7 flex items-center justify-between text-xs font-semibold text-white shrink-0 z-40 pointer-events-none select-none">
              <span className="font-mono">{currentTime}</span>
              <div className="flex items-center gap-1.5 text-neutral-300">
                <Wifi className="w-3.5 h-3.5" />
                <span className="text-[10px] font-bold">5G</span>
                <Battery className="w-4 h-4" />
              </div>
            </div>

            {/* Host App View Container */}
            <div className="flex-1 relative overflow-hidden">
              <SimulatedHostApp
                onFpsUpdate={setCurrentFps}
                cpuLoadFactor={cpuLoadFactor}
                onSetCpuLoadFactor={setCpuLoadFactor}
                isStressTesting={stressTest.status === 'running'}
                allocatedStressMB={stressTest.allocatedMB}
              />

              {/* Floating PiP Monitor inside Phone Container */}
              <FloatingPiP
                telemetry={telemetry}
                settings={pipSettings}
                visible={isPipVisible}
                onOpenDashboard={() => setIsDashboardOpen(true)}
                onToggleVisible={() => setIsPipVisible(false)}
                containerRef={containerRef}
              />
            </div>

            {/* iOS Home Indicator Bar */}
            <div className="h-6 w-full flex items-center justify-center shrink-0 z-40 pointer-events-none">
              <div className="w-32 h-1 bg-white/40 rounded-full" />
            </div>
          </div>
        ) : (
          /* Full Viewport View */
          <div className="w-full h-full relative overflow-hidden">
            <SimulatedHostApp
              onFpsUpdate={setCurrentFps}
              cpuLoadFactor={cpuLoadFactor}
              onSetCpuLoadFactor={setCpuLoadFactor}
              isStressTesting={stressTest.status === 'running'}
              allocatedStressMB={stressTest.allocatedMB}
            />

            <FloatingPiP
              telemetry={telemetry}
              settings={pipSettings}
              visible={isPipVisible}
              onOpenDashboard={() => setIsDashboardOpen(true)}
              onToggleVisible={() => setIsPipVisible(false)}
              containerRef={containerRef}
            />
          </div>
        )}
      </main>

      {/* Fullscreen Diagnostic Dashboard Modal */}
      <DashboardModal
        telemetry={telemetry}
        settings={pipSettings}
        isOpen={isDashboardOpen}
        onClose={() => setIsDashboardOpen(false)}
        onRunStressTest={() => setAlertState({ isOpen: true, type: 'confirm' })}
        onUpdateSettings={handleUpdateSettings}
      />

      {/* 4-Finger Touch Tutorial Overlay */}
      <TutorialOverlay
        isOpen={isTutorialOpen}
        onCompleted={handleTutorialCompleted}
        onSimulateFourFingerTap={() => setIsPipVisible((prev) => !prev)}
        onSimulateFourFingerHold={() => setIsDashboardOpen(true)}
      />

      {/* iOS Native Style Alert Modals */}
      <OOMAlertModal
        type={alertState.type}
        isOpen={alertState.isOpen}
        allocatedMB={alertState.allocatedMB}
        onConfirm={handleStartStressTestConfirmed}
        onCancel={() => setAlertState({ isOpen: false, type: 'confirm' })}
      />

      {/* Setup Guide Modal */}
      <SetupGuideModal
        isOpen={isSetupGuideOpen}
        onClose={() => setIsSetupGuideOpen(false)}
      />
    </div>
  );
}
