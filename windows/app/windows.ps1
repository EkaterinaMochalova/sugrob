$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class SugrobWindow {
    public string id; public int x, y, width, height;
}
public static class SugrobDesktop {
    public delegate bool Callback(IntPtr h, IntPtr p);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool EnumWindows(Callback cb, IntPtr p);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder text, int length);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    public static bool ControlHeld() { return (GetAsyncKeyState(0x11) & 0x8000) != 0; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("dwmapi.dll", EntryPoint="DwmGetWindowAttribute")] static extern int Frame(IntPtr h, int a, out Rect r, int size);
    [DllImport("dwmapi.dll", EntryPoint="DwmGetWindowAttribute")] static extern int Attribute(IntPtr h, int a, out int v, int size);
    public static SugrobWindow[] Read(uint exclude) {
        SetProcessDPIAware();
        var list = new List<SugrobWindow>();
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid == exclude || !IsWindowVisible(h) || IsIconic(h)) return true;
            int cloaked; Attribute(h, 14, out cloaked, 4); if (cloaked != 0) return true;
            var cls = new StringBuilder(256); GetClassName(h, cls, 256);
            if (cls.ToString() == "Progman" || cls.ToString() == "WorkerW" || cls.ToString().Contains("Shell_")) return true;
            Rect r; if (Frame(h, 9, out r, 16) != 0 && !GetWindowRect(h, out r)) return true;
            if (r.Right-r.Left < 40 || r.Bottom-r.Top < 25) return true;
            list.Add(new SugrobWindow { id=h.ToInt64().ToString(), x=r.Left, y=r.Top, width=r.Right-r.Left, height=r.Bottom-r.Top });
            return list.Count < 200;
        }, IntPtr.Zero);
        return list.ToArray();
    }
}
'@
$tick = 0
$windows = @()
while ($true) {
    if ($tick % 10 -eq 0) { $windows = @([SugrobDesktop]::Read(__SUGROB_PID__)) }
    $tick++
    $snapshot = @{ windows = $windows; ctrl = [SugrobDesktop]::ControlHeld(); foreground = [SugrobDesktop]::GetForegroundWindow().ToInt64().ToString() }
    ConvertTo-Json -InputObject $snapshot -Compress -Depth 4
    Start-Sleep -Milliseconds 50
}
