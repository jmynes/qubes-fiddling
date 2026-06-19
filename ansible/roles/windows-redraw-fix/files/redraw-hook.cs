using System;
using System.Runtime.InteropServices;
using System.Text;
class RedrawHook {
  // ---- window lifecycle ----
  delegate void WinEventProc(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time);
  [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint mn, uint mx, IntPtr hmod, WinEventProc proc, uint pid, uint tid, uint flags);
  // ---- low-level mouse hook (scoped to desktop drags only) ----
  delegate IntPtr HookProc(int code, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc proc, IntPtr hmod, uint tid);
  [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr w, IntPtr l);
  [DllImport("kernel32.dll", CharSet = CharSet.Auto)] static extern IntPtr GetModuleHandle(string n);
  // ---- hit-test the surface under the cursor ----
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern int GetClassName(IntPtr h, StringBuilder s, int max);
  // ---- paint + loop ----
  [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr h, IntPtr rc, IntPtr rgn, uint flags);
  [DllImport("user32.dll")] static extern UIntPtr SetTimer(IntPtr h, UIntPtr id, uint ms, IntPtr proc);
  [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint mn, uint mx);
  [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG m);
  [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref MSG m);
  [StructLayout(LayoutKind.Sequential)] struct POINT { public int x, y; }
  [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr w; public IntPtr l; public uint time; public int x; public int y; }

  const uint RDW = 0x1 | 0x4 | 0x80 | 0x100; // INVALIDATE|ERASE|ALLCHILDREN|UPDATENOW
  const uint OUTOFCONTEXT = 0, SKIPOWN = 2, GA_ROOT = 2;
  const uint MOVESIZEEND = 0x000B, MINIMIZESTART = 0x0016, MINIMIZEEND = 0x0017, DESTROY = 0x8001, HIDE = 0x8003, LOCATIONCHANGE = 0x800B;
  const int WH_MOUSE_LL = 14, WM_MOUSEMOVE = 0x200, WM_LBUTTONDOWN = 0x201, WM_LBUTTONUP = 0x202, WM_TIMER = 0x0113;
  const int CATCHALL_MS = 200;

  static int lastLoc = 0;
  static bool dragDesktop = false, pending = false;
  static WinEventProc _we = WinCb;
  static HookProc _mh = MouseCb;

  static void Full() { RedrawWindow(IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, RDW); }

  // discrete window events -> one repaint each (never in-app interaction)
  static void WinCb(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time) {
    if (idObj != 0 || idChild != 0) return;
    if (ev == MOVESIZEEND || ev == MINIMIZESTART || ev == MINIMIZEEND || ev == DESTROY || ev == HIDE) { Full(); return; }
    if (ev == LOCATIONCHANGE) { int now = Environment.TickCount; if (now - lastLoc < CATCHALL_MS) return; lastLoc = now; Full(); }
  }

  // is the cursor over the desktop shell (not an app window)?
  static bool OnDesktop() {
    POINT p; if (!GetCursorPos(out p)) return false;
    IntPtr h = WindowFromPoint(p);
    if (h == IntPtr.Zero) return false;
    IntPtr root = GetAncestor(h, GA_ROOT);
    var sb = new StringBuilder(64);
    GetClassName(root, sb, 64);
    string c = sb.ToString();
    return c == "Progman" || c == "WorkerW";   // the desktop's root window classes
  }

  // Arms only when a left-drag begins on the desktop, and repaints ONCE on
  // release -- not during the drag. Repainting mid-drag with RDW_ERASE wiped the
  // live marquee rectangle every frame (it took ~1s to become visible); the
  // post-release repaint clears the leftover selection/icon trail just fine.
  // App drags never arm OnDesktop(), so app performance is untouched.
  static IntPtr MouseCb(int code, IntPtr w, IntPtr l) {
    if (code >= 0) {
      int msg = w.ToInt32();
      if (msg == WM_LBUTTONDOWN) dragDesktop = OnDesktop();
      else if (msg == WM_LBUTTONUP) { if (dragDesktop) pending = true; dragDesktop = false; }
    }
    return CallNextHookEx(IntPtr.Zero, code, w, l);
  }

  static void Main() {
    SetWinEventHook(MOVESIZEEND, MINIMIZEEND, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(DESTROY, DESTROY, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(HIDE, HIDE, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(LOCATIONCHANGE, LOCATIONCHANGE, IntPtr.Zero, _we, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWindowsHookEx(WH_MOUSE_LL, _mh, GetModuleHandle(null), 0);
    SetTimer(IntPtr.Zero, UIntPtr.Zero, 50, IntPtr.Zero); // ~20Hz flush, only acts during a desktop drag
    MSG m;
    while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) {
      if (m.message == WM_TIMER) { if (pending) { pending = false; Full(); } }
      TranslateMessage(ref m); DispatchMessage(ref m);
    }
  }
}
