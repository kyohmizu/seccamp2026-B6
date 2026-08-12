// FlowPay backend: 経費API。private な Cloud Run サービスとして稼働させ、frontend からのみ呼び出す。
package main

import (
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/rs/zerolog"
)

func main() {
	logger := zerolog.New(os.Stdout).With().Timestamp().Str("service", "backend").Logger()

	store := NewStore()
	store.Seed()
	api := NewAPI(store, logger)

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(requestLogger(logger))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{http.MethodGet, http.MethodPost},
		AllowedHeaders: []string{"Content-Type"},
	}))

	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })
	r.Get("/expenses", api.list)
	r.Post("/expenses", api.create)
	r.Get("/expenses/{id}", api.get)
	r.Get("/summary", api.summary)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	logger.Info().Str("port", port).Msg("backend listening")
	srv := &http.Server{Addr: ":" + port, Handler: r, ReadHeaderTimeout: 5 * time.Second}
	if err := srv.ListenAndServe(); err != nil {
		logger.Fatal().Err(err).Msg("server stopped")
	}
}

// requestLogger は各リクエストを zerolog で構造化ログに残すミドルウェア。
func requestLogger(logger zerolog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			next.ServeHTTP(ww, r)
			logger.Info().
				Str("method", r.Method).
				Str("path", r.URL.Path).
				Int("status", ww.Status()).
				Dur("dur", time.Since(start)).
				Str("reqID", middleware.GetReqID(r.Context())).
				Msg("request")
		})
	}
}
