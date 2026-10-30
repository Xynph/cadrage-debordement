package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"unsafe"
)

func acquireLock(path string) (func(), error) {
	p, e := syscall.UTF16PtrFromString(path)
	if e != nil {
		return nil, e
	}
	h, e := syscall.CreateFile(p, syscall.GENERIC_READ|syscall.GENERIC_WRITE, 0, nil, syscall.OPEN_ALWAYS, syscall.FILE_ATTRIBUTE_NORMAL, 0)
	if e != nil {
		return nil, e
	}
	return func() { syscall.CloseHandle(h) }, nil
}
func openBrowser(url, profile string) error {
	candidates := []string{filepath.Join(os.Getenv("ProgramFiles(x86)"), "Microsoft", "Edge", "Application", "msedge.exe"), filepath.Join(os.Getenv("ProgramFiles"), "Microsoft", "Edge", "Application", "msedge.exe"), filepath.Join(os.Getenv("LOCALAPPDATA"), "Microsoft", "Edge", "Application", "msedge.exe"), filepath.Join(os.Getenv("ProgramFiles"), "Google", "Chrome", "Application", "chrome.exe"), filepath.Join(os.Getenv("LOCALAPPDATA"), "Google", "Chrome", "Application", "chrome.exe")}
	for _, p := range candidates {
		if st, e := os.Stat(p); e == nil && !st.IsDir() {
			cmd := exec.Command(p, "--app="+url, "--user-data-dir="+profile, "--no-first-run", "--no-default-browser-check")
			if e = cmd.Start(); e == nil {
				return cmd.Process.Release()
			}
		}
	}
	cmd := exec.Command("rundll32.exe", "url.dll,FileProtocolHandler", url)
	if e := cmd.Start(); e != nil {
		return fmt.Errorf("ouvrez Edge ou Chrome, puis relancez le jeu : %w", e)
	}
	return cmd.Process.Release()
}
func openFolder(path string) error {
	cmd := exec.Command("explorer.exe", path)
	if e := cmd.Start(); e != nil {
		return e
	}
	return cmd.Process.Release()
}
func notifyError(message string) {
	title, _ := syscall.UTF16PtrFromString("Cadrage Débordement")
	body, _ := syscall.UTF16PtrFromString(message)
	_, _, _ = syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(body)), uintptr(unsafe.Pointer(title)), 0x10)
}
