package main

import (
	"crypto/rand"
	"crypto/subtle"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

//go:embed app
var assets embed.FS
var version = "16.0.0"

const cookieName = "cadrage_local"
const maxRequest = 16 << 20

type diskState struct {
	Version  int               `json:"version"`
	Revision uint64            `json:"revision"`
	Items    map[string]string `json:"items"`
}
type storage struct {
	sync.Mutex
	Dir       string
	State     diskState
	Recovered bool
}
type instance struct {
	URL   string `json:"url"`
	Token string `json:"token"`
}
type application struct {
	store               *storage
	token, host, origin string
	shutdown            chan struct{}
	once                sync.Once
	activity            sync.Mutex
	lastSeen            time.Time
}

func validItems(items map[string]string) bool {
	if items == nil || len(items) > 64 {
		return false
	}
	size := 0
	for k, v := range items {
		if !strings.HasPrefix(k, "bdt-") || len(k) > 80 || len(v) > 6<<20 {
			return false
		}
		size += len(k) + len(v)
	}
	return size <= 32<<20
}
func readState(path string) (diskState, error) {
	var state diskState
	f, err := os.Open(path)
	if err != nil {
		return state, err
	}
	defer f.Close()
	raw, err := io.ReadAll(io.LimitReader(f, 64<<20+1))
	if err != nil || len(raw) > 64<<20 {
		return state, errors.New("fichier de sauvegarde trop volumineux")
	}
	err = json.Unmarshal(raw, &state)
	if err != nil || state.Version != 1 || !validItems(state.Items) {
		return state, errors.New("fichier de sauvegarde illisible")
	}
	return state, nil
}
func loadStorage(dir string) (*storage, error) {
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	s := &storage{Dir: dir, State: diskState{Version: 1, Items: map[string]string{}}}
	mainPath := filepath.Join(dir, "donnees.json")
	primary, err := readState(mainPath)
	if err == nil {
		s.State = primary
		return s, nil
	}
	backup, backErr := readState(filepath.Join(dir, "donnees-precedentes.json"))
	if os.IsNotExist(err) && os.IsNotExist(backErr) {
		return s, nil
	}
	if backErr != nil {
		return nil, fmt.Errorf("sauvegarde illisible ; les fichiers ont été conservés dans %s", dir)
	}
	if !os.IsNotExist(err) {
		b, readErr := os.ReadFile(mainPath)
		if readErr != nil {
			return nil, readErr
		}
		if e := atomicWrite(filepath.Join(dir, "donnees-illisibles-"+time.Now().Format("20060102-150405.000")+".json"), b); e != nil {
			return nil, e
		}
	}
	s.State = backup
	s.Recovered = true
	return s, nil
}
func atomicWrite(path string, b []byte) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".cadrage-*.tmp")
	if err != nil {
		return err
	}
	tmp := f.Name()
	defer os.Remove(tmp)
	if err = f.Chmod(0600); err == nil {
		_, err = f.Write(b)
	}
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
func (s *storage) change(revision uint64, key string, value *string) (uint64, error) {
	s.Lock()
	defer s.Unlock()
	if revision != s.State.Revision {
		return s.State.Revision, errors.New("conflict")
	}
	next := diskState{Version: 1, Revision: s.State.Revision + 1, Items: map[string]string{}}
	for k, v := range s.State.Items {
		next.Items[k] = v
	}
	if value == nil {
		delete(next.Items, key)
	} else {
		next.Items[key] = *value
	}
	if !strings.HasPrefix(key, "bdt-") || len(key) > 80 || !validItems(next.Items) {
		return s.State.Revision, errors.New("données hors limites")
	}
	old, err := json.Marshal(s.State)
	if err != nil {
		return s.State.Revision, err
	}
	raw, err := json.Marshal(next)
	if err != nil {
		return s.State.Revision, err
	}
	if err = atomicWrite(filepath.Join(s.Dir, "donnees-precedentes.json"), old); err != nil {
		return s.State.Revision, err
	}
	if err = atomicWrite(filepath.Join(s.Dir, "donnees.json"), raw); err != nil {
		return s.State.Revision, err
	}
	s.State = next
	return next.Revision, nil
}
func (a *application) stop() { a.once.Do(func() { close(a.shutdown) }) }
func (a *application) authenticated(r *http.Request) bool {
	c, err := r.Cookie(cookieName)
	return err == nil && subtle.ConstantTimeCompare([]byte(c.Value), []byte(a.token)) == 1
}
func (a *application) touch() { a.activity.Lock(); a.lastSeen = time.Now(); a.activity.Unlock() }
func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(v)
}
func (a *application) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
	if r.Host != a.host {
		http.Error(w, "Hôte refusé", 403)
		return
	}
	if r.URL.Path == "/api/health" {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("X-CD-Token")), []byte(a.token)) != 1 {
			http.Error(w, "Accès refusé", 403)
			return
		}
		writeJSON(w, map[string]string{"application": "cadrage-debordement", "version": version})
		return
	}
	if r.URL.Path == "/" && r.URL.Query().Get("session") != "" {
		if subtle.ConstantTimeCompare([]byte(r.URL.Query().Get("session")), []byte(a.token)) != 1 {
			http.Error(w, "Relancez CadrageDebordement.exe", 403)
			return
		}
		http.SetCookie(w, &http.Cookie{Name: cookieName, Value: a.token, Path: "/", HttpOnly: true, SameSite: http.SameSiteStrictMode})
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	if !a.authenticated(r) {
		http.Error(w, "Ouvrez le jeu avec CadrageDebordement.exe.", 403)
		return
	}
	if strings.HasPrefix(r.URL.Path, "/api/") {
		if r.Header.Get("X-CD-Local") != "1" || (r.Header.Get("Origin") != "" && r.Header.Get("Origin") != a.origin) {
			http.Error(w, "Origine refusée", 403)
			return
		}
		a.touch()
		switch r.URL.Path {
		case "/api/storage":
			if r.Method == "GET" {
				a.store.Lock()
				defer a.store.Unlock()
				writeJSON(w, map[string]any{"items": a.store.State.Items, "revision": a.store.State.Revision, "directory": a.store.Dir, "recovered": a.store.Recovered})
				return
			}
			if r.Method != "POST" {
				http.Error(w, "Méthode refusée", 405)
				return
			}
			var op struct {
				Revision *uint64 `json:"revision"`
				Key      string  `json:"key"`
				Value    *string `json:"value"`
			}
			d := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxRequest))
			d.DisallowUnknownFields()
			if err := d.Decode(&op); err != nil || op.Revision == nil {
				http.Error(w, "Données invalides", 400)
				return
			}
			var extra any
			if d.Decode(&extra) != io.EOF {
				http.Error(w, "Données invalides", 400)
				return
			}
			rev, err := a.store.change(*op.Revision, op.Key, op.Value)
			if err != nil {
				status := 500
				if err.Error() == "conflict" {
					status = 409
				}
				http.Error(w, "Écriture refusée : "+err.Error(), status)
				return
			}
			writeJSON(w, map[string]uint64{"revision": rev})
		case "/api/heartbeat":
			if r.Method != "GET" {
				http.Error(w, "Méthode refusée", 405)
				return
			}
			writeJSON(w, map[string]bool{"ok": true})
		case "/api/open-folder":
			if r.Method != "POST" {
				http.Error(w, "Méthode refusée", 405)
				return
			}
			if err := openFolder(a.store.Dir); err != nil {
				http.Error(w, "Dossier indisponible", 500)
				return
			}
			writeJSON(w, map[string]bool{"ok": true})
		case "/api/quit":
			if r.Method != "POST" {
				http.Error(w, "Méthode refusée", 405)
				return
			}
			writeJSON(w, map[string]bool{"ok": true})
			go func() { time.Sleep(200 * time.Millisecond); a.stop() }()
		default:
			http.NotFound(w, r)
		}
		return
	}
	if r.Method != "GET" && r.Method != "HEAD" {
		http.Error(w, "Méthode refusée", 405)
		return
	}
	f, _ := fs.Sub(assets, "app")
	http.FileServer(http.FS(f)).ServeHTTP(w, r)
}
func dataDirectory() (string, error) {
	if p := os.Getenv("LOCALAPPDATA"); p != "" {
		return filepath.Join(p, "CadrageDebordement"), nil
	}
	p, e := os.UserConfigDir()
	return filepath.Join(p, "CadrageDebordement"), e
}
func launchExisting(path string) error {
	b, e := os.ReadFile(path)
	if e != nil {
		return errors.New("une autre instance démarre ; réessayez dans quelques secondes")
	}
	var in instance
	if json.Unmarshal(b, &in) != nil {
		return errors.New("une instance du jeu est déjà ouverte")
	}
	req, e := http.NewRequest("GET", in.URL+"/api/health", nil)
	if e != nil {
		return e
	}
	if !strings.HasPrefix(in.URL, "http://127.0.0.1:") {
		return errors.New("adresse locale invalide")
	}
	req.Header.Set("X-CD-Token", in.Token)
	client := &http.Client{Timeout: 3 * time.Second}
	res, e := client.Do(req)
	if e != nil {
		return errors.New("le jeu est déjà ouvert mais ne répond pas ; fermez-le avant de réessayer")
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return errors.New("instance locale indisponible")
	}
	dir, _ := dataDirectory()
	return openBrowser(in.URL+"/?session="+in.Token, filepath.Join(dir, "Profil"))
}
func run() error {
	headless := flag.Bool("headless", false, "Tester le serveur sans ouvrir le navigateur")
	data := flag.String("data-dir", "", "Dossier de données personnalisé")
	ready := flag.String("ready-file", "", "Fichier de démarrage pour les tests")
	flag.Parse()
	dir := *data
	if dir == "" {
		var err error
		dir, err = dataDirectory()
		if err != nil {
			return err
		}
	}
	abs, e := filepath.Abs(dir)
	if e != nil {
		return e
	}
	dir = abs
	if e = os.MkdirAll(dir, 0700); e != nil {
		return e
	}
	unlock, e := acquireLock(filepath.Join(dir, "application.lock"))
	if e != nil {
		return launchExisting(filepath.Join(dir, "instance.json"))
	}
	defer unlock()
	store, e := loadStorage(dir)
	if e != nil {
		return e
	}
	listener, e := net.Listen("tcp4", "127.0.0.1:0")
	if e != nil {
		return e
	}
	defer listener.Close()
	bytes := make([]byte, 32)
	if _, e = rand.Read(bytes); e != nil {
		return e
	}
	token := hex.EncodeToString(bytes)
	host := listener.Addr().String()
	origin := "http://" + host
	a := &application{store: store, token: token, host: host, origin: origin, shutdown: make(chan struct{}), lastSeen: time.Now()}
	info, _ := json.Marshal(instance{URL: origin, Token: token})
	if e = atomicWrite(filepath.Join(dir, "instance.json"), info); e != nil {
		return e
	}
	defer os.Remove(filepath.Join(dir, "instance.json"))
	if *ready != "" {
		if e = atomicWrite(*ready, info); e != nil {
			return e
		}
	}
	server := &http.Server{Handler: a, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 15 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 32 << 10}
	defer server.Close()
	failures := make(chan error, 1)
	go func() { failures <- server.Serve(listener) }()
	if !*headless {
		if e = openBrowser(origin+"/?session="+token, filepath.Join(dir, "Profil")); e != nil {
			return e
		}
	}
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt)
	defer signal.Stop(signals)
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-a.shutdown:
			return nil
		case <-signals:
			return nil
		case e := <-failures:
			if errors.Is(e, http.ErrServerClosed) {
				return nil
			}
			return e
		case <-ticker.C:
			a.activity.Lock()
			idle := time.Since(a.lastSeen)
			a.activity.Unlock()
			if idle > 5*time.Minute {
				return nil
			}
		}
	}
}
func main() {
	if err := run(); err != nil {
		notifyError("Cadrage Débordement\n\n" + err.Error())
		os.Exit(1)
	}
}
