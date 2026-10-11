package main

import (
	"fmt"
	"net/http"
	"time"
)

// checkHealth は url に GET し、HTTP 200 なら nil を返す。
// ECS のコンテナヘルスチェック（タスク定義の healthCheck）から
// `/server -healthcheck` として呼ばれる。distroless には curl もシェルも
// 無いため、アプリのバイナリ自身が HTTP クライアントとして自分の /healthz を叩く。
func checkHealth(url string) error {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}
	return nil
}
