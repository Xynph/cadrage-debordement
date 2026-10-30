package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestStoragePersistenceConflictAndRecovery(t *testing.T) {
	dir := t.TempDir()
	s, e := loadStorage(dir)
	if e != nil {
		t.Fatal(e)
	}
	v := "carrière éè <test>"
	rev, e := s.change(0, "bdt-v1", &v)
	if e != nil || rev != 1 {
		t.Fatal(e, rev)
	}
	loaded, e := loadStorage(dir)
	if e != nil || loaded.State.Items["bdt-v1"] != v {
		t.Fatal(e)
	}
	if _, e = s.change(0, "bdt-v1", nil); e == nil {
		t.Fatal("écriture obsolète acceptée")
	}
	if _, e = s.change(1, "autre", &v); e == nil {
		t.Fatal("clé inconnue acceptée")
	}
	v2 := "nouvel état"
	if _, e = s.change(1, "bdt-v1", &v2); e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(dir, "donnees.json"), []byte("corrompu"), 0600); e != nil {
		t.Fatal(e)
	}
	recovered, e := loadStorage(dir)
	if e != nil || !recovered.Recovered || recovered.State.Items["bdt-v1"] != v {
		t.Fatal("copie précédente non récupérée", e)
	}
	files, _ := filepath.Glob(filepath.Join(dir, "donnees-illisibles-*.json"))
	if len(files) != 1 {
		t.Fatal("fichier illisible non conservé")
	}
	if _, e = recovered.change(recovered.State.Revision, "bdt-v1", nil); e != nil {
		t.Fatal(e)
	}
	again, e := loadStorage(dir)
	if e != nil || len(again.State.Items) != 0 {
		t.Fatal(e)
	}
}
func TestUnreadableStorageAndFailedWrite(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "donnees.json"), []byte("{cassé"), 0600)
	if _, e := loadStorage(dir); e == nil {
		t.Fatal("stockage illisible réinitialisé")
	}
	dir2 := t.TempDir()
	s, _ := loadStorage(dir2)
	os.Mkdir(filepath.Join(dir2, "donnees.json"), 0700)
	v := "préserver"
	if _, e := s.change(0, "bdt-v1", &v); e == nil {
		t.Fatal("échec d’écriture non signalé")
	}
	if s.State.Revision != 0 || len(s.State.Items) != 0 {
		t.Fatal("mémoire modifiée après échec")
	}
}
func TestExclusiveLock(t *testing.T) {
	dir := t.TempDir()
	unlock, e := acquireLock(filepath.Join(dir, "test.lock"))
	if e != nil {
		t.Fatal(e)
	}
	if second, e := acquireLock(filepath.Join(dir, "test.lock")); e == nil {
		second()
		t.Fatal("double verrou")
	}
	unlock()
	next, e := acquireLock(filepath.Join(dir, "test.lock"))
	if e != nil {
		t.Fatal(e)
	}
	next()
}
func TestHTTPIsolationAndOperations(t *testing.T) {
	s, _ := loadStorage(t.TempDir())
	a := &application{store: s, token: "secret-test", host: "127.0.0.1:12345", origin: "http://127.0.0.1:12345", shutdown: make(chan struct{}), lastSeen: time.Now()}
	req := func(method, path, body string, auth bool, origin string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, a.origin+path, strings.NewReader(body))
		if auth {
			r.AddCookie(&http.Cookie{Name: cookieName, Value: a.token})
			r.Header.Set("X-CD-Local", "1")
		}
		if origin != "" {
			r.Header.Set("Origin", origin)
		}
		w := httptest.NewRecorder()
		a.ServeHTTP(w, r)
		return w
	}
	if w := req("GET", "/", "", false, ""); w.Code != 403 {
		t.Fatal(w.Code)
	}
	if w := req("GET", "/?session=secret-test", "", false, ""); w.Code != 303 || len(w.Result().Cookies()) != 1 || !w.Result().Cookies()[0].HttpOnly {
		t.Fatal("amorçage invalide")
	}
	if w := req("GET", "/api/storage", "", false, ""); w.Code != 403 {
		t.Fatal("accès non authentifié")
	}
	if w := req("POST", "/api/storage", `{"revision":0,"key":"bdt-v1","value":"carrière"}`, true, "https://externe.invalid"); w.Code != 403 {
		t.Fatal("origine externe acceptée")
	}
	if w := req("POST", "/api/storage", `{"revision":0,"key":"bdt-v1","value":"carrière"}`, true, a.origin); w.Code != 200 {
		t.Fatal(w.Code, w.Body.String())
	}
	if w := req("POST", "/api/storage", `{"revision":0,"key":"bdt-v1","value":"écrasé"}`, true, a.origin); w.Code != 409 {
		t.Fatal("conflit non détecté")
	}
	w := req("GET", "/api/storage", "", true, a.origin)
	var result map[string]any
	if json.Unmarshal(w.Body.Bytes(), &result) != nil || result["items"].(map[string]any)["bdt-v1"] != "carrière" {
		t.Fatal("état perdu")
	}
	if w := req("GET", "/", "", true, ""); w.Code != 200 || !strings.Contains(w.Body.String(), "offline-bridge.js") {
		t.Fatal("jeu embarqué absent", w.Code)
	}
	if w := req("GET", "/fonts/DMSans-Variable.ttf", "", true, ""); w.Code != 200 || w.Body.Len() < 1000 {
		t.Fatal("police locale absente")
	}
	if w := req("GET", "/../donnees.json", "", true, ""); w.Code == 200 {
		t.Fatal("lecture hors ressources")
	}
	if w := req("GET", "/api/quit", "", true, ""); w.Code != 405 {
		t.Fatal("arrêt par GET accepté")
	}
	if w := req("POST", "/api/quit", "", true, a.origin); w.Code != 200 {
		t.Fatal("arrêt impossible")
	}
	select {
	case <-a.shutdown:
	case <-time.After(time.Second):
		t.Fatal("arrêt non effectué")
	}
}
