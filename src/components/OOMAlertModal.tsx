import React from 'react';
import { AlertTriangle, AlertOctagon } from 'lucide-react';

interface OOMAlertModalProps {
  type: 'confirm' | 'result';
  isOpen: boolean;
  allocatedMB?: number;
  onConfirm?: () => void;
  onCancel: () => void;
}

export const OOMAlertModal: React.FC<OOMAlertModalProps> = ({
  type,
  isOpen,
  allocatedMB = 0,
  onConfirm,
  onCancel,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-150">
      <div className="w-full max-w-[270px] rounded-[14px] bg-[#252528]/95 backdrop-blur-2xl border border-white/20 shadow-2xl text-center overflow-hidden animate-in zoom-in-95 duration-150">
        <div className="p-4 pt-5 pb-4">
          <div className="flex justify-center mb-2">
            {type === 'confirm' ? (
              <div className="w-9 h-9 rounded-full bg-amber-500/20 text-amber-400 flex items-center justify-center">
                <AlertTriangle className="w-5 h-5" />
              </div>
            ) : (
              <div className="w-9 h-9 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center">
                <AlertOctagon className="w-5 h-5" />
              </div>
            )}
          </div>

          <h3 className="text-[17px] font-semibold text-white tracking-tight leading-tight mb-1.5">
            {type === 'confirm' ? 'Warning' : 'RAM Test Result (Crash OOM)'}
          </h3>

          <p className="text-[13px] text-neutral-300 leading-snug">
            {type === 'confirm' ? (
              'This test will allocate RAM until the app crashes to measure limits. Continue?'
            ) : (
              <>
                App crashed due to Out Of Memory!
                <br />
                <span className="font-semibold text-red-300">
                  Max allocated RAM before crash: {allocatedMB} MB
                </span>
              </>
            )}
          </p>
        </div>

        {/* iOS Native Style Alert Buttons */}
        {type === 'confirm' ? (
          <div className="grid grid-cols-2 border-t border-white/15 divide-x divide-white/15">
            <button
              onClick={onCancel}
              className="py-3 text-[16px] text-blue-400 font-normal hover:bg-white/5 active:bg-white/10 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={onConfirm}
              className="py-3 text-[16px] text-red-500 font-semibold hover:bg-white/5 active:bg-white/10 transition-colors"
            >
              Start
            </button>
          </div>
        ) : (
          <div className="border-t border-white/15">
            <button
              onClick={onCancel}
              className="w-full py-3 text-[16px] text-blue-400 font-semibold hover:bg-white/5 active:bg-white/10 transition-colors"
            >
              OK
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
