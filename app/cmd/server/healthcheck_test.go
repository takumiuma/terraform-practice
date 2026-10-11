package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// happy-path: 200 を返すサーバーなら成功。
func TestCheckHealth_OK(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	if err := checkHealth(srv.URL); err != nil {
		t.Fatalf("expected nil, got %v", err)
	}
}

// error-path 1: 200 以外ならエラー。
func TestCheckHealth_NonOK(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	if err := checkHealth(srv.URL); err == nil {
		t.Fatal("expected error for 503, got nil")
	}
}

// error-path 2: 接続できなければエラー。
func TestCheckHealth_Unreachable(t *testing.T) {
	srv := httptest.NewServer(http.NotFoundHandler())
	url := srv.URL
	srv.Close()

	if err := checkHealth(url); err == nil {
		t.Fatal("expected error for unreachable server, got nil")
	}
}
