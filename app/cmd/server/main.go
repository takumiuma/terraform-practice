// gin-ecs-cheap のエントリポイント。
// ECS Fargate 上で動く Gin サーバーを起動する。
package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/example/gin-ecs-cheap/internal/handler"
)

func main() {
	// -healthcheck: ECS のコンテナヘルスチェック用。サーバーは起動せず、
	// 起動中の自分の /healthz を叩いて結果を終了コード（0=正常, 1=異常）で返す。
	healthcheck := flag.Bool("healthcheck", false, "check /healthz of the running server and exit")
	flag.Parse()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	if *healthcheck {
		if err := checkHealth("http://127.0.0.1:" + port + "/healthz"); err != nil {
			log.Fatalf("healthcheck failed: %v", err)
		}
		os.Exit(0)
	}

	// 本番相当モード。エラーレスポンスに内部情報を出さない。
	gin.SetMode(gin.ReleaseMode)

	// DB 接続（未設定なら skeleton モードで /healthz のみ）。
	db, err := handler.OpenDB()
	if err != nil {
		log.Fatalf("database initialization failed: %v", err)
	}

	router := handler.NewRouter(db)

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// サーバーを別 goroutine で起動。
	go func() {
		log.Printf("listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	// SIGINT / SIGTERM を受けてグレースフルシャットダウン。
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
	log.Println("server stopped")
}
