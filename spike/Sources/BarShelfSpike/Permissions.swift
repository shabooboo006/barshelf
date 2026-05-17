import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics

enum Permissions {
    static func report() {
        let ax = AXIsProcessTrusted()
        let screen = CGPreflightScreenCaptureAccess()
        Log.line("辅助功能 已授权 = \(ax)")
        Log.line("屏幕录制 已授权 = \(screen)")

        if !ax {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
            Log.line("已请求辅助功能（若未授权，系统会弹出对话框；授权后需重启本 App）。")
        }
        if !screen {
            let ok = CGRequestScreenCaptureAccess()
            Log.line("已请求屏幕录制，立即结果 = \(ok)（需在 系统设置▸隐私与安全性▸屏幕录制 勾选 BarShelfSpike 并重启本 App）。")
        }
        if ax && screen {
            Log.line("两项权限均已授权，可继续 ② 扫描。")
        } else {
            Log.line("⚠️ 两项权限必须都为 true 才能继续。请授权后退出并重新打开本 App，再次点 ①。")
        }
    }
}
