using System;
using System.Runtime.InteropServices;
class RedrawHook {
  // ---- WinEvent hook: window lifecycle (close / minimize / move-resize end) ----
  delegate void WinEventProc(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time);
  [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint mn, uint mx, IntPtr hmod, WinEventProc proc, uint pid, uint tid, uint flags);
  // ---- low-level mouse hook: catches desktop marquee / icon drag / any live drag ----
  delegate IntPtr HookProc(int code, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr hmod, uint tid);
  [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr w, IntPtr l);
  [DllImport("kernel32.dll", CharSet = CharSet.Auto)] static extern IntPtr GetModuleHandle(string name);
  // ---- paint + message loop ----
  [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr hWnd, IntPtr lprc, IntPtr rgn, uint flags);
  [DllImport("user32.dll")] static extern UIntPtr SetTimer(IntPtr hWnd, UIntPtr id, uint ms, IntPtr proc);
  [DllImport("user32.dll")] static extern int GetMessage(out MSG msg, IntPtr hWnd, uint mn, uint mx);
  [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG msg);
  [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref MSG msg);
  [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr w; public IntPtr l; public uint time; public int x; public int y; }

  const uint RDW = 0x1 | 0x4 | 0x80 | 0x100; // INVALIDATE|ERASE|ALLCHILDREN|UPDATENOW
  const uint OUTOFCONTEXT = 0, SKIPOWN = 2;
  const uint MOVESIZEEND = 0x000B, MINIMIZESTART = 0x0016, MINIMIZEEND = 0x0017, DESTROY = 0x8001, HIDE = 0x8003, LOCATIONCHANGE = 0x800B;
  const int WH_MOUSE_LL = 14, WM_MOUSEMOVE = 0x200, WM_LBUTTONDOWN = 0x201, WM_LBUTTONUP = 0x202, WM_TIMER = 0x0113;
  const int CATCHALL_MS = 200;

  static bool dragging = false, pending = false;
  static int lastLoc = 0;
  static WinEventProc _we = WinCb;
  static HookProc _mh = MouseCb;

  static void Full() { RedrawWindow(IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, RDW); }

  static void WinCb(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time) {
    if (idObj != 0 || idChild != 0) return;
    if (ev == MOVESIZEEND || ev == MINIMIZESTART || ev == MINIMIZEEND || ev == DESTROY || ev == HIDE) { Full(); return; }
    if (ev == LOCATIONCHANGE) { int now = Environment.TickCount; if (now - lastLoc < CATCHALL_MS) return; lastLoc = now; Full(); }
  }

  // Only sets flags -- the actual repaint runs in the timer handler on the main
  // thread, so we never do heavy work inside the low-level hook (avoids the LL
  // hook timeout and paint reentrancy).
  static IntPtr MouseCb(int code, IntPtr w, IntPtr l) {
    if (code >= 0) {
      int msg = w.ToInt32();
      if (msg == WM_LBUTTONDOWN) dragging = true;
      else if (msg == WM_LBUTTONUP) { dragging = false; pending = true; }   // final clear on release
      else if (msg == WM_MOUSEMOVE && dragging) pending = true;
    }
    return CallNextHookEx(IntPtr.Zero, code, w, l);
  }

  static void Main() {
    SetWinEventHook(MOVESIZEEND, MINIMIZEEND, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(DESTROY, DESTROY, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(HIDE, HIDE, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(LOCATIONCHANGE, LOCATIONCHANGE, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWindowsHookEx(WH_MOUSE_LL, _mh, GetModuleHandle(null), 0);
    SetTimer(IntPtr.Zero, UIntPtr.Zero, 40, IntPtr.Zero); // ~25Hz flush, but only acts while pending (i.e. during a drag)
    MSG m;
    while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) {
      if (m.message == WM_TIMER) { if (pending) { pending = false; Full(); } }
      TranslateMessage(ref m); DispatchMessage(ref m);
    }
  }
}
