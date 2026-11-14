# Shared P/Invoke type for console-mode tests (dot-sourced)
if (-not ('ConMode' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ConMode {
    [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
    [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern IntPtr CreateFileW(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)]
    public struct KEY_EVENT_RECORD {
        [FieldOffset(0)] public int bKeyDown;
        [FieldOffset(4)] public ushort wRepeatCount;
        [FieldOffset(6)] public ushort wVirtualKeyCode;
        [FieldOffset(8)] public ushort wVirtualScanCode;
        [FieldOffset(10)] public char UnicodeChar;
        [FieldOffset(12)] public uint dwControlKeyState;
    }
    [StructLayout(LayoutKind.Explicit)]
    public struct INPUT_RECORD {
        [FieldOffset(0)] public ushort EventType;
        [FieldOffset(4)] public KEY_EVENT_RECORD KeyEvent;
    }
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool WriteConsoleInputW(IntPtr h, INPUT_RECORD[] recs, uint n, out uint written);
    public static uint InMode() { uint m; GetConsoleMode(GetStdHandle(-10), out m); return m; }
    public static uint ConinMode() {
        IntPtr h = CreateFileW("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        uint m; if (!GetConsoleMode(h, out m)) return 0xFFFFFFFF; CloseHandle(h); return m;
    }
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] public struct COORD { public short X; public short Y; }
    [StructLayout(LayoutKind.Sequential)] public struct SMALL_RECT { public short L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct CSBI { public COORD Size; public COORD Cursor; public ushort Attr; public SMALL_RECT Win; public COORD Max; }
    [DllImport("kernel32.dll")] public static extern bool GetConsoleScreenBufferInfo(IntPtr h, out CSBI i);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool ReadConsoleOutputCharacterW(IntPtr h, System.Text.StringBuilder sb, uint len, COORD c, out uint read);
    public static string ScreenTail(int lines) {
        IntPtr h = CreateFileW("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        CSBI i; if (!GetConsoleScreenBufferInfo(h, out i)) { CloseHandle(h); return "<no screen>"; }
        var sb = new System.Text.StringBuilder();
        int start = Math.Max(0, i.Cursor.Y - lines + 1);
        for (int y = start; y <= i.Cursor.Y; y++) {
            var row = new System.Text.StringBuilder(i.Size.X + 1); uint r; COORD c; c.X = 0; c.Y = (short)y;
            ReadConsoleOutputCharacterW(h, row, (uint)i.Size.X, c, out r);
            sb.AppendLine(row.ToString().TrimEnd());
        }
        CloseHandle(h); return sb.ToString();
    }
    public static bool SendKeys(string s) {
        IntPtr h = CreateFileW("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        var list = new System.Collections.Generic.List<INPUT_RECORD>();
        foreach (char c in s) {
            ushort vk = (c == '\r') ? (ushort)0x0D : (ushort)Char.ToUpper(c);
            for (int d = 1; d >= 0; d--) {
                var r = new INPUT_RECORD(); r.EventType = 1;
                r.KeyEvent.bKeyDown = d; r.KeyEvent.wRepeatCount = 1;
                r.KeyEvent.wVirtualKeyCode = vk; r.KeyEvent.UnicodeChar = c;
                list.Add(r);
            }
        }
        uint w; return WriteConsoleInputW(h, list.ToArray(), (uint)list.Count, out w);
    }
}
'@
}
