#!/usr/bin/env python3
"""Explicit X11/XTest actions only. Importing/compiling this file sends nothing."""
import argparse
import ctypes as C
import ctypes.util
import datetime
import json
import os
from pathlib import Path
import time

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['inspect', 'return', 'back'])
    parser.add_argument('--log', default='/workspace/work/native-os-input/os-input-actions.jsonl')
    args = parser.parse_args()
    x11 = C.CDLL(ctypes.util.find_library('X11') or 'libX11.so.6')
    xtst = C.CDLL(ctypes.util.find_library('Xtst') or 'libXtst.so.6')
    Display = C.c_void_p
    Window = C.c_ulong
    x11.XOpenDisplay.argtypes = [C.c_char_p]; x11.XOpenDisplay.restype = Display
    x11.XCloseDisplay.argtypes = [Display]
    x11.XGetInputFocus.argtypes = [Display, C.POINTER(Window), C.POINTER(C.c_int)]
    x11.XDefaultRootWindow.argtypes = [Display]; x11.XDefaultRootWindow.restype = Window
    x11.XFetchName.argtypes = [Display, Window, C.POINTER(C.c_void_p)]; x11.XFetchName.restype = C.c_int
    x11.XQueryTree.argtypes = [Display, Window, C.POINTER(Window), C.POINTER(Window), C.POINTER(C.POINTER(Window)), C.POINTER(C.c_uint)]
    x11.XFree.argtypes = [C.c_void_p]
    x11.XStringToKeysym.argtypes = [C.c_char_p]; x11.XStringToKeysym.restype = C.c_ulong
    x11.XKeysymToKeycode.argtypes = [Display, C.c_ulong]; x11.XKeysymToKeycode.restype = C.c_ubyte
    x11.XSync.argtypes = [Display, C.c_int]
    xtst.XTestFakeKeyEvent.argtypes = [Display, C.c_uint, C.c_int, C.c_ulong]; xtst.XTestFakeKeyEvent.restype = C.c_int
    display = x11.XOpenDisplay(None)
    if not display:
        raise SystemExit('Unable to open DISPLAY=' + os.environ.get('DISPLAY', ''))
    def title(window):
        ptr = C.c_void_p()
        if window > 1 and x11.XFetchName(display, Window(window), C.byref(ptr)) and ptr.value:
            try:
                return C.string_at(ptr.value).decode('utf-8', errors='replace')
            finally:
                x11.XFree(ptr)
        return ''
    def snapshot():
        focus = Window(); revert = C.c_int()
        x11.XGetInputFocus(display, C.byref(focus), C.byref(revert))
        root = x11.XDefaultRootWindow(display)
        root_ret = Window(); parent_ret = Window(); children = C.POINTER(Window)(); count = C.c_uint()
        windows = []
        if x11.XQueryTree(display, root, C.byref(root_ret), C.byref(parent_ret), C.byref(children), C.byref(count)):
            try:
                for index in range(min(count.value, 100)):
                    value = int(children[index])
                    windows.append({'id': value, 'hex': hex(value), 'title': title(value)})
            finally:
                if children: x11.XFree(children)
        return {'focus_window': int(focus.value), 'focus_hex': hex(focus.value), 'focus_title': title(focus.value), 'revert_to': revert.value, 'root_windows': windows}
    def send(name, down):
        keysym = x11.XStringToKeysym(name.encode('ascii'))
        keycode = x11.XKeysymToKeycode(display, keysym)
        if not keycode: raise RuntimeError('No keycode for ' + name)
        if not xtst.XTestFakeKeyEvent(display, keycode, int(down), 0):
            raise RuntimeError('XTestFakeKeyEvent failed for ' + name)
        x11.XSync(display, 0)
    try:
        record = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'display': os.environ.get('DISPLAY'), 'action': args.action, 'before': snapshot(), 'transport': 'X11 libXtst XTestFakeKeyEvent', 'target': 'current X11 focus; no focus manipulation'}
        if args.action != 'inspect' and record['before']['focus_window'] <= 1:
            raise RuntimeError('No application X11 input focus; refusing to send keys')
        if args.action == 'return':
            send('Return', True)
            time.sleep(0.06)
            send('Return', False)
        elif args.action == 'back':
            send('Alt_L', True)
            try:
                send('Left', True)
                time.sleep(0.06)
                send('Left', False)
            finally:
                send('Alt_L', False)
        record['after'] = snapshot()
        log = Path(args.log)
        with log.open('a') as stream:
            stream.write(json.dumps(record, ensure_ascii=False) + '\n')
        print(json.dumps(record, ensure_ascii=False, indent=2))
    finally:
        x11.XCloseDisplay(display)

if __name__ == '__main__':
    main()
