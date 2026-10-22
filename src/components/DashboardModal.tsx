import React, { useState } from 'react';
import { TelemetryData } from '../types.ts';
import { formatDec, triggerHaptic } from '../utils/telemetry.ts';
import {
  Activity,
  Share2,
  XCircle,
  Smartphone,
  Settings2,
  Layers,
  Bug,
  Cpu,
  Database,
  HardDrive,
  Gauge,
  ExternalLink,
  Check,
  Flame,
  Globe,
} from 'lucide-react';

interface DashboardModalProps {
  telemetry: TelemetryData;
  isOpen: boolean;
  onClose: () => void;
  onRunStressTest: () => void;
}

export const DashboardModal: React.FC<DashboardModalProps> = ({
  telemetry,
  isOpen,
  onClose,
  onRunStressTest,
}) => {
  const [copiedToast, setCopiedToast] = useState<string | null>(null);

  if (!isOpen) return null;

  const items = [
    {
      id: 'model',
      icon: <Smartphone className="w-5 h-5 text-cyan-400" />,
      title: 'Device Model',
      value: telemetry.deviceModel,
    },
    {
      id: 'version',
      icon: <Settings2 className="w-5 h-5 text-cyan-400" />,
      title: 'iOS Version',
      value: telemetry.iosVersion,
    },
    {
      id: 'bundle',
      icon: <Layers className="w-5 h-5 text-cyan-400" />,
      title: 'Bundle ID',
      value: telemetry.bundleId,
    },
    {
      id: 'debugger',
      icon: <Bug className="w-5 h-5 text-cyan-400" />,
      title: 'Debugger Attached',
      value: telemetry.debuggerAttached ? 'Yes (Connected)' : 'No (Clean)',
    },
    {
      id: 'kernel',
      icon: <Cpu className="w-5 h-5 text-cyan-400" />,
      title: 'Memory+ Kernel',
      value: 'Active',
    },
    {
      id: 'appRam',
      icon: <Database className="w-5 h-5 text-cyan-400" />,
      title: 'App RAM Usage',
      value: `${formatDec(telemetry.ramMB)} MB`,
    },
    {
      id: 'totalRam',
      icon: <HardDrive className="w-5 h-5 text-cyan-400" />,
      title: 'Total Device RAM',
      value: `${telemetry.totalDeviceRamMB} MB`,
    },
    {
      id: 'fps',
      icon: <Gauge className="w-5 h-5 text-cyan-400" />,
      title: 'Render Framerate',
      value: `${formatDec(telemetry.fps)} FPS`,
    },
    {
      id: 'thermal',
      icon: <Flame className="w-5 h-5 text-cyan-400" />,
      title: 'Thermal State',
      value: telemetry.thermalState,
    },
  ];

  const diagnosticSummary = `📊 PerfMonitor Diagnostics
------------------------
Device Model: ${telemetry.deviceModel}
iOS Version: ${telemetry.iosVersion}
Bundle ID: ${telemetry.bundleId}
Debugger Attached: ${telemetry.debuggerAttached ? 'Yes' : 'No'}
Memory+ Kernel: Active
App RAM Usage: ${formatDec(telemetry.ramMB)} MB
Total Device RAM: ${telemetry.totalDeviceRamMB} MB
Render FPS: ${formatDec(telemetry.fps)} FPS
Thermal State: ${telemetry.thermalState}`;

  const handleCopyRow = (val: string, label: string) => {
    triggerHaptic('light');
    navigator.clipboard.writeText(val).catch(() => {});
    showToast(`Copied ${label} to clipboard!`);
  };

  const handleShare = async () => {
    triggerHaptic('medium');
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'PerfMonitor Diagnostics',
          text: diagnosticSummary,
        });
        return;
      } catch {
        // Fallback to copy
      }
    }
    navigator.clipboard.writeText(diagnosticSummary);
    showToast('Diagnostic summary copied to clipboard!');
  };

  const showToast = (msg: string) => {
    setCopiedToast(msg);
    setTimeout(() => {
      setCopiedToast(null);
    }, 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-black/60 backdrop-blur-xl animate-in fade-in duration-200">
      {/* Container Card */}
      <div className="relative w-full max-w-[460px] max-h-[92vh] flex flex-col rounded-[26px] bg-[#1e1e22]/90 border border-white/15 shadow-2xl overflow-hidden backdrop-blur-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-white/10 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="p-1.5 rounded-lg bg-blue-500/20 text-blue-400 animate-pulse-slow">
              <Activity className="w-5 h-5" />
            </div>
            <h2 className="text-[17px] font-bold text-white tracking-tight">
              Performance Dashboard
            </h2>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleShare}
              title="Share Diagnostics"
              className="p-2 rounded-full text-blue-400 hover:bg-white/10 transition-colors active:scale-95"
            >
              <Share2 className="w-5 h-5" />
            </button>
            <button
              onClick={onClose}
              title="Close Dashboard"
              className="p-1 rounded-full text-white/50 hover:text-white transition-colors active:scale-95"
            >
              <XCircle className="w-7 h-7" />
            </button>
          </div>
        </div>

        {/* Scrollable Diagnostics List */}
        <div className="flex-1 overflow-y-auto px-4 py-3 space-y-2.5 divide-y-0">
          {items.map((item) => (
            <button
              key={item.id}
              onClick={() => handleCopyRow(item.value, item.title)}
              className="w-full flex items-center justify-between px-3.5 py-3 rounded-xl bg-white/[0.05] hover:bg-white/[0.09] active:bg-white/[0.14] border border-white/[0.06] transition-all text-left group"
            >
              <div className="flex items-center gap-3">
                <div className="p-1.5 rounded-lg bg-black/30 group-hover:scale-105 transition-transform">
                  {item.icon}
                </div>
                <span className="text-[13px] font-medium text-neutral-300">
                  {item.title}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-[13px] font-bold text-white font-mono tracking-tight">
                  {item.value}
                </span>
              </div>
            </button>
          ))}
        </div>

        {/* Action Button: Run RAM Stress Test */}
        <div className="px-4 pt-2 pb-3 shrink-0">
          <button
            onClick={() => {
              triggerHaptic('medium');
              onRunStressTest();
            }}
            className="w-full py-3 px-4 rounded-xl bg-red-600 hover:bg-red-500 active:bg-red-700 text-white font-bold text-[14px] shadow-lg shadow-red-950/40 transition-all flex items-center justify-center gap-2 active:scale-[0.98]"
          >
            <Flame className="w-4 h-4" />
            <span>Run RAM Stress Test (OOM)</span>
          </button>
        </div>

        {/* Footer: Created by Eksemekse-dev with AI + Planet/Globe GitHub Button */}
        <div className="flex items-center justify-between px-5 py-3.5 bg-black/40 border-t border-white/10 shrink-0">
          <span className="text-[11px] font-medium text-neutral-400">
            Created by Eksemekse-dev with AI
          </span>
          <a
            href="https://github.com/Eksemekse-dev/iOS-PerfMonitor"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-blue-600/20 hover:bg-blue-600/30 border border-blue-500/30 text-blue-400 hover:text-blue-300 font-bold text-xs transition-all active:scale-95"
            title="Open GitHub Repository"
          >
            <Globe className="w-3.5 h-3.5 text-blue-400" />
            <span>GitHub</span>
            <ExternalLink className="w-3 h-3 opacity-60 ml-0.5" />
          </a>
        </div>

        {/* Floating Toast Notification */}
        {copiedToast && (
          <div className="absolute bottom-20 left-1/2 -translate-x-1/2 px-4 py-2 rounded-full bg-black/90 border border-white/20 text-white text-xs font-semibold shadow-2xl flex items-center gap-1.5 animate-in fade-in zoom-in-95 pointer-events-none">
            <Check className="w-3.5 h-3.5 text-emerald-400" />
            <span>{copiedToast}</span>
          </div>
        )}
      </div>
    </div>
  );
};
