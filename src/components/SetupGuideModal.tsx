import React from 'react';
import { X, BookOpen, Layers, Terminal, Sparkles, Download, CheckCircle2 } from 'lucide-react';

interface SetupGuideModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SetupGuideModal: React.FC<SetupGuideModalProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  const steps = [
    {
      step: 1,
      title: 'Download Compiled Binary',
      description: 'Acquire the compiled PerfMonitor.dylib from the repository releases or compile using Theos.',
      detail: 'Built for iphone:clang:latest:14.0 arm64/arm64e with UIKit, CoreGraphics, and QuartzCore frameworks.',
    },
    {
      step: 2,
      title: 'Open LiveContainer',
      description: 'Launch LiveContainer on your iOS device and locate your target application container.',
      detail: 'LiveContainer enables JIT and dynamic dylib injection in sandboxed user space.',
    },
    {
      step: 3,
      title: 'Configure Tweak Injection',
      description: 'Navigate to app settings → Tweak Injection → Add Dynamic Library (.dylib).',
      detail: 'Select PerfMonitor.dylib from Files or the local documents storage.',
    },
    {
      step: 4,
      title: 'Verify Permissions & Window Hook',
      description: 'Ensure the dylib constructor executes with UIWindowLevelAlert priority.',
      detail: 'The dylib constructs an independent UIWindow overlaying root view controllers.',
    },
    {
      step: 5,
      title: 'Launch & Trigger Gestures',
      description: 'Launch the host application. Use a 4-finger tap to show/hide PiP, or hold 4 fingers for 2s for Dashboard.',
      detail: 'Includes OOM crash detection, mach task_info resident memory inspection, and thermal telemetry.',
    },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-black/70 backdrop-blur-xl animate-in fade-in duration-200">
      <div className="relative w-full max-w-[560px] max-h-[90vh] flex flex-col rounded-3xl bg-[#1a1b24] border border-white/15 shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-white/10 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-cyan-500/20 text-cyan-400">
              <BookOpen className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white leading-tight">
                Installation & Architecture Guide
              </h3>
              <p className="text-xs text-neutral-400">Eksemekse-dev/iOS-PerfMonitor</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-full text-white/50 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto px-6 py-5 space-y-5">
          {/* Architecture Card */}
          <div className="p-4 rounded-2xl bg-cyan-950/30 border border-cyan-500/30 space-y-2">
            <div className="flex items-center gap-2 text-cyan-300 text-xs font-bold uppercase tracking-wider">
              <Terminal className="w-4 h-4" />
              Technical Architecture
            </div>
            <p className="text-xs text-neutral-300 leading-relaxed">
              Compiled via <code className="text-cyan-300 font-mono">clang</code> for{' '}
              <code className="text-cyan-300 font-mono">iphoneos</code>, the library injects
              directly into the target process lifecycle, establishing an independent high-priority{' '}
              <code className="text-cyan-300 font-mono">UIWindow (UIWindowLevelAlert)</code> that
              persists across application transitions without interfering with the host app’s UI
              hierarchy.
            </p>
          </div>

          {/* Steps */}
          <div className="space-y-3">
            <h4 className="text-xs font-bold uppercase tracking-wider text-neutral-400">
              Step-by-Step Deployment
            </h4>
            {steps.map((s) => (
              <div
                key={s.step}
                className="p-3.5 rounded-xl bg-white/[0.04] border border-white/10 flex items-start gap-3.5"
              >
                <div className="w-6 h-6 rounded-full bg-cyan-500/20 text-cyan-300 font-bold text-xs flex items-center justify-center shrink-0 mt-0.5">
                  {s.step}
                </div>
                <div className="flex-1">
                  <div className="text-sm font-bold text-white mb-0.5">{s.title}</div>
                  <div className="text-xs text-neutral-300 mb-1">{s.description}</div>
                  <div className="text-[11px] text-neutral-400 font-mono bg-black/40 px-2 py-1 rounded-md border border-white/5">
                    {s.detail}
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Gesture Controls Reference */}
          <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-2.5">
            <h4 className="text-xs font-bold uppercase tracking-wider text-neutral-400 flex items-center gap-1.5">
              <Sparkles className="w-4 h-4 text-purple-400" />
              Native Gesture Triggers
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
              <div className="p-2.5 rounded-lg bg-black/40 border border-white/5">
                <span className="font-bold text-cyan-300">4-Finger Tap:</span>
                <p className="text-neutral-400 mt-0.5">Show or hide the floating Performance PiP.</p>
              </div>
              <div className="p-2.5 rounded-lg bg-black/40 border border-white/5">
                <span className="font-bold text-purple-300">4-Finger Long Press (2s):</span>
                <p className="text-neutral-400 mt-0.5">Open the full-screen Performance Dashboard.</p>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 bg-black/40 border-t border-white/10 flex items-center justify-between shrink-0">
          <span className="text-xs text-neutral-400">iOS-PerfMonitor v1.0.0</span>
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl bg-white/10 hover:bg-white/20 text-white text-xs font-bold transition-all"
          >
            Close Guide
          </button>
        </div>
      </div>
    </div>
  );
};
