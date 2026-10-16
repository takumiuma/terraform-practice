package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// happy-path: /healthz は 200 を返す。
func TestHealthz_OK(t *testing.T) {
	router := NewRouter(nil)

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if got := rec.Body.String(); got != `{"status":"ok"}` {
		t.Fatalf("unexpected body: %s", got)
	}
}

// error-path 1: 未定義パスは 404。
func TestUnknownRoute_NotFound(t *testing.T) {
	router := NewRouter(nil)

	req := httptest.NewRequest(http.MethodGet, "/nope", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
	if got := rec.Body.String(); got != `{"error":"not found"}` {
		t.Fatalf("unexpected body: %s", got)
	}
}

// error-path 2: skeleton モード（db=nil）では /items は登録されず 404。
func TestItemsRoute_SkeletonMode_NotFound(t *testing.T) {
	router := NewRouter(nil)

	req := httptest.NewRequest(http.MethodGet, "/items", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404 in skeleton mode, got %d", rec.Code)
	}
}

// newSQLiteRouter は一時ディレクトリの SQLite（Lambda 構成と同じドライバ）で DB ありのルーターを作る。
func newSQLiteRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db, err := OpenSQLite(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	return NewRouter(db)
}

func doRequest(router *gin.Engine, method, path, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

// happy-path: 作成 → 一覧 → 削除 → 一覧 が仕様どおりのステータスで返る。
func TestItems_CreateListDelete(t *testing.T) {
	router := newSQLiteRouter(t)

	rec := doRequest(router, http.MethodPost, "/items", `{"name":"はじめてのアイテム"}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d (%s)", rec.Code, rec.Body.String())
	}
	var created Item
	if err := json.Unmarshal(rec.Body.Bytes(), &created); err != nil {
		t.Fatalf("create: decode: %v", err)
	}
	if created.ID == 0 || created.Name != "はじめてのアイテム" || created.CreatedAt.IsZero() {
		t.Fatalf("create: unexpected item: %+v", created)
	}

	rec = doRequest(router, http.MethodGet, "/items", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("list: expected 200, got %d", rec.Code)
	}
	var items []Item
	if err := json.Unmarshal(rec.Body.Bytes(), &items); err != nil {
		t.Fatalf("list: decode: %v", err)
	}
	if len(items) != 1 || items[0].ID != created.ID {
		t.Fatalf("list: unexpected items: %+v", items)
	}

	rec = doRequest(router, http.MethodDelete, "/items/"+strconv.FormatUint(uint64(created.ID), 10), "")
	if rec.Code != http.StatusOK {
		t.Fatalf("delete: expected 200, got %d", rec.Code)
	}
	if want := `{"deleted":` + strconv.FormatUint(uint64(created.ID), 10) + `}`; rec.Body.String() != want {
		t.Fatalf("delete: unexpected body: %s", rec.Body.String())
	}

	rec = doRequest(router, http.MethodGet, "/items", "")
	if rec.Code != http.StatusOK || rec.Body.String() != `[]` {
		t.Fatalf("list after delete: got %d %s", rec.Code, rec.Body.String())
	}
}

// error-path: 不正な入力・存在しない ID。
func TestItems_Errors(t *testing.T) {
	router := newSQLiteRouter(t)

	cases := []struct {
		name, method, path, body string
		want                     int
	}{
		{"create invalid json", http.MethodPost, "/items", `{`, http.StatusBadRequest},
		{"create empty name", http.MethodPost, "/items", `{"name":""}`, http.StatusBadRequest},
		{"delete non-numeric id", http.MethodDelete, "/items/abc", "", http.StatusBadRequest},
		{"delete missing id", http.MethodDelete, "/items/999", "", http.StatusNotFound},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := doRequest(router, tc.method, tc.path, tc.body)
			if rec.Code != tc.want {
				t.Fatalf("expected %d, got %d (%s)", tc.want, rec.Code, rec.Body.String())
			}
		})
	}
}
