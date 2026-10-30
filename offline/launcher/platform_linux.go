package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

func acquireLock(path string) (func(), error) {
	f, e := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if e != nil {
		return nil, e
	}
	if e = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); e != nil {
		f.Close()
		return nil, e
	}
	return func() { syscall.Flock(int(f.Fd()), syscall.LOCK_UN); f.Close() }, nil
}
func openBrowser(url, profile string) error {
	c := exec.Command("xdg-open", url)
	if e := c.Start(); e != nil {
		return e
	}
	return c.Process.Release()
}
func openFolder(path string) error {
	c := exec.Command("xdg-open", path)
	if e := c.Start(); e != nil {
		return e
	}
	return c.Process.Release()
}
func notifyError(message string) { fmt.Fprintln(os.Stderr, message) }
