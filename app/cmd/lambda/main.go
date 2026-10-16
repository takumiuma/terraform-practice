// Lambda（Function URL）用のエントリポイント。
// ECS 版（cmd/server）と同じ Gin ルーターを、aws-lambda-go-api-proxy 経由で
// Lambda のイベント（payload v2.0）に載せて動かす。
package main

import (
	"log"

	"github.com/aws/aws-lambda-go/lambda"
	ginadapter "github.com/awslabs/aws-lambda-go-api-proxy/gin"
	"github.com/gin-gonic/gin"

	"github.com/example/gin-ecs-cheap/internal/handler"
)

func main() {
	gin.SetMode(gin.ReleaseMode)

	// DB はコールドスタート時に 1 回だけ開き、ウォーム実行間で使い回す。
	// Lambda では DB_DRIVER=sqlite / DB_PATH=/mnt/data/app.db（EFS）を渡す。
	db, err := handler.OpenDB()
	if err != nil {
		log.Fatalf("database initialization failed: %v", err)
	}

	// Function URL のイベントは API Gateway HTTP API（payload v2.0）と同形式なので V2 アダプタを使う。
	adapter := ginadapter.NewV2(handler.NewRouter(db))
	lambda.Start(adapter.ProxyWithContext)
}
