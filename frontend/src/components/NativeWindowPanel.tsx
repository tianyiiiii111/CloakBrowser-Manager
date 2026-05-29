import { useState } from "react";
import { Code2, Monitor } from "lucide-react";

interface NativeWindowPanelProps {
  profileId: string;
  cdpUrl: string | null;
}

export function NativeWindowPanel({ profileId, cdpUrl }: NativeWindowPanelProps) {
  const [cdpCopied, setCdpCopied] = useState(false);

  const fullCdpUrl = cdpUrl
    ? `${window.location.origin}${cdpUrl}`
    : `${window.location.origin}/api/profiles/${profileId}/cdp`;

  const copyCdp = async () => {
    await navigator.clipboard.writeText(fullCdpUrl);
    setCdpCopied(true);
    setTimeout(() => setCdpCopied(false), 2000);
  };

  return (
    <div className="flex items-center justify-center h-full p-8">
      <div className="max-w-md text-center space-y-4">
        <div className="flex justify-center">
          <div className="p-4 rounded-full bg-surface-2 border border-border">
            <Monitor className="h-8 w-8 text-indigo-400" />
          </div>
        </div>
        <h2 className="text-lg font-medium text-gray-100">已在原生窗口中运行</h2>
        <p className="text-sm text-gray-400 leading-relaxed">
          CloakBrowser 已在系统独立窗口中打开。请在该窗口中浏览；
          本面板用于配置控制与自动化连接。
        </p>
        <button
          onClick={copyCdp}
          className="inline-flex items-center gap-2 px-3 py-1.5 text-xs rounded-md bg-surface-2 border border-border text-gray-300 hover:text-gray-100 hover:border-gray-600 transition-colors"
        >
          <Code2 className="h-3.5 w-3.5" />
          {cdpCopied ? "已复制 CDP 地址" : "复制 CDP 地址"}
        </button>
      </div>
    </div>
  );
}
