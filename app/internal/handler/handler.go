// Package handler は Gin の HTTP ハンドラとルーティングを提供する。
package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// Item は学習用の最小データモデル。GORM の AutoMigrate で 1 テーブルを作る。
type Item struct {
	ID   uint   `gorm:"primaryKey" json:"id"`
	Name string `gorm:"size:255;not null" json:"name" binding:"required"`
}

// NewRouter は依存（DB）を受け取り、ルーティングを構成した *gin.Engine を返す。
// db が nil の場合は DB 非依存のエンドポイント（/healthz）だけが機能する
// walking skeleton 構成として動作する。
func NewRouter(db *gorm.DB) *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	// ヘルスチェック。DB に依存せず常に 200 を返す（ECS ヘルスチェック用）。
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	if db != nil {
		registerItemRoutes(r, db)
	}

	return r
}

// registerItemRoutes は MySQL 上の Item に対する最小の read/write（作成・一覧）を登録する。
func registerItemRoutes(r *gin.Engine, db *gorm.DB) {
	// 作成: POST /items {"name": "..."}
	r.POST("/items", func(c *gin.Context) {
		var in Item
		if err := c.ShouldBindJSON(&in); err != nil {
			// 境界でエラーを HTTP に変換。内部情報は返さない。
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
			return
		}
		item := Item{Name: in.Name}
		if err := db.Create(&item).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create item"})
			return
		}
		c.JSON(http.StatusCreated, item)
	})

	// 一覧: GET /items
	r.GET("/items", func(c *gin.Context) {
		var items []Item
		if err := db.Find(&items).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list items"})
			return
		}
		c.JSON(http.StatusOK, items)
	})
}
