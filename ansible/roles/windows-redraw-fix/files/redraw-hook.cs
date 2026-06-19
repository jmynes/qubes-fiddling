using System;
using System.Runtime.InteropServices;
class RedrawHook {
  delegate void WinEventProc(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time);
  [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint mn, uint mx, IntPtr hmod, WinEventProc proc, uint pid, uint tid, uint flags);
  [DllImport("user32.dll")] static extern bool RedrawWindow(IntPtr hWnd, IntPtr lprc, IntPtr rgn, uint flags);
  [DllImport("user32.dll")] static extern int GetMessage(out MSG msg, IntPtr hWnd, uint mn, uint mx);
  [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG msg);
  [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref MSG msg);
  [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr w; public IntPtr l; public uint time; public int x; public int y; }

  const uint OUTOFCONTEXT = 0, SKIPOWN = 2;
  // INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW -- a reliable forced full repaint.
  const uint RDW = 0x1 | 0x4 | 0x80 | 0x100;
  const uint MOVESIZEEND = 0x000B, MINIMIZESTART = 0x0016, MINIMIZEEND = 0x0017;
  const uint DESTROY = 0x8001, HIDE = 0x8003, LOCATIONCHANGE = 0x800B;

  // Catch-all throttle: bounds cost when something moves windows programmatically.
  const int CATCHALL_MS = 200;
  static int last = 0;
  static WinEventProc _p = Cb;

  static void Full() { RedrawWindow(IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, RDW); }

  // ONLY discrete window-level events fire a repaint -- never in-app dragging /
  // scrolling / pane resizing, so this does not touch app performance.
  static void Cb(IntPtr hook, uint ev, IntPtr hwnd, int idObj, int idChild, uint thread, uint time) {
    if (idObj != 0 || idChild != 0) return;               // top-level window object only
    if (ev == MOVESIZEEND || ev == MINIMIZESTART || ev == MINIMIZEEND || ev == DESTROY || ev == HIDE) {
      Full();
      return;
    }
    if (ev == LOCATIONCHANGE) {                            // programmatic window moves, throttled
      int now = Environment.TickCount;
      if (now - last < CATCHALL_MS) return;
      last = now;
      Full();
    }
  }

  static void Main() {
    SetWinEventHook(MOVESIZEEND, MINIMIZEEND, IntPtr.Zero, _p, 0, 0, OUTOFCONTEXT | SKIPOWN); // 0x000B..0x0017
    SetWinEventHook(DESTROY, DESTROY, IntPtr.Zero, _p, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(HIDE, HIDE, IntPtr.Zero, _p, 0, 0, OUTOFCONTEXT | SKIPOWN);
    SetWinEventHook(LOCATIONCHANGE, LOCATIONCHANGE, IntPtr.Zero, _p, 0, 0, OUTOFCONTEXT | SKIPOWN);
    MSG m;
    while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) { TranslateMessage(ref m); DispatchMessage(ref m); }
  }
}
