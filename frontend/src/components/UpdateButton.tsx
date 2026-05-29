import { useCallback, useEffect, useState } from "react";
import { Download, Loader2, RefreshCw } from "lucide-react";
import { api, type UpdateCheckResult } from "../lib/api";

type Phase = "idle" | "checking" | "ready" | "updating" | "error";

export function UpdateButton() {
  const [open, setOpen] = useState(false);
  const [phase, setPhase] = useState<Phase>("idle");
  const [info, setInfo] = useState<UpdateCheckResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [appVersion, setAppVersion] = useState<string>("");

  const check = useCallback(async () => {
    setPhase("checking");
    setError(null);
    try {
      const result = await api.checkUpdate();
      setInfo(result);
      setPhase("ready");
    } catch (e) {
      setError(e instanceof Error ? e.message : "检查更新失败");
      setPhase("error");
    }
  }, []);

  useEffect(() => {
    api.getStatus()
      .then((s) => setAppVersion(s.app_version))
      .catch(() => {});
    check();
  }, [check]);

  const apply = async () => {
    if (!info?.can_apply_in_app) return;
    setPhase("updating");
    setError(null);
    try {
      await api.applyUpdate();
    } catch (e) {
      setError(e instanceof Error ? e.message : "更新失败");
      setPhase("ready");
    }
  };

  const badge =
    info?.update_available && phase !== "updating" ? (
      <span className="absolute -top-0.5 -right-0.5 h-2 w-2 rounded-full bg-amber-400" />
    ) : null;

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="relative text-gray-500 hover:text-gray-300 p-1"
        title="检查更新"
      >
        <RefreshCw
          className={`h-3.5 w-3.5 ${phase === "checking" ? "animate-spin" : ""}`}
        />
        {badge}
      </button>

      {open && (
        <>
          <div
            className="fixed inset-0 z-40"
            onClick={() => setOpen(false)}
            aria-hidden
          />
          <div className="absolute right-0 top-full mt-2 z-50 w-80 rounded-lg border border-border bg-surface-2 shadow-xl p-4 text-sm">
            <div className="flex items-center justify-between mb-2">
              <span className="font-medium text-gray-200">软件更新</span>
              <button
                type="button"
                onClick={check}
                disabled={phase === "checking" || phase === "updating"}
                className="text-xs text-gray-500 hover:text-gray-300"
              >
                重新检查
              </button>
            </div>

            <p className="text-xs text-gray-500 mb-3">
              当前版本 v{info?.current_version ?? (appVersion || "—")}
            </p>

            {phase === "checking" && (
              <p className="text-gray-400 text-xs flex items-center gap-2">
                <Loader2 className="h-3 w-3 animate-spin" /> 正在检查…
              </p>
            )}

            {error && (
              <p className="text-red-400 text-xs mb-2">{error}</p>
            )}

            {info && phase !== "checking" && (
              <>
                {info.update_available ? (
                  <p className="text-amber-300 text-xs mb-3">
                    发现新版本 v{info.latest_version}
                  </p>
                ) : (
                  <p className="text-green-400/90 text-xs mb-3">已是最新版本</p>
                )}

                {info.release_notes && (
                  <pre className="text-xs text-gray-500 max-h-24 overflow-y-auto whitespace-pre-wrap mb-3 border border-border rounded p-2 bg-surface-1">
                    {info.release_notes.slice(0, 500)}
                    {info.release_notes.length > 500 ? "…" : ""}
                  </pre>
                )}

                {info.update_available && info.can_apply_in_app && (
                  <button
                    type="button"
                    onClick={apply}
                    disabled={phase === "updating"}
                    className="w-full flex items-center justify-center gap-2 rounded-md bg-amber-600 hover:bg-amber-500 disabled:opacity-50 text-white text-xs py-2 px-3"
                  >
                    {phase === "updating" ? (
                      <>
                        <Loader2 className="h-3.5 w-3.5 animate-spin" />
                        正在下载并更新…
                      </>
                    ) : (
                      <>
                        <Download className="h-3.5 w-3.5" />
                        一键更新并重启
                      </>
                    )}
                  </button>
                )}

                {info.update_available && !info.can_apply_in_app && (
                  <a
                    href={info.release_url}
                    target="_blank"
                    rel="noreferrer"
                    className="block text-center text-xs text-amber-400 hover:underline"
                  >
                    前往发布页下载
                  </a>
                )}
              </>
            )}
          </div>
        </>
      )}
    </div>
  );
}
