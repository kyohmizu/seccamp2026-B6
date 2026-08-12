package main

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-playground/validator/v10"
	"github.com/rs/zerolog"
)

// API は HTTP ハンドラの依存をまとめる。
type API struct {
	store    *Store
	validate *validator.Validate
	log      zerolog.Logger
}

func NewAPI(store *Store, log zerolog.Logger) *API {
	return &API{store: store, validate: validator.New(), log: log}
}

// createExpenseRequest は登録リクエストの入力。validator タグで検証する。
type createExpenseRequest struct {
	Amount   int64  `json:"amount" validate:"required,gt=0,lte=100000000"`
	Memo     string `json:"memo" validate:"max=200"`
	Category string `json:"category" validate:"omitempty,oneof=交通費 会議費 消耗品 出張費 接待費 その他"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// list は一覧を返す。?category= / ?from= / ?to=（RFC3339）で絞り込める。
func (a *API) list(w http.ResponseWriter, r *http.Request) {
	f := Filter{Category: r.URL.Query().Get("category")}
	if v := r.URL.Query().Get("from"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			f.From = t
		}
	}
	if v := r.URL.Query().Get("to"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			f.To = t
		}
	}
	writeJSON(w, http.StatusOK, a.store.List(f))
}

// create は1件登録する。入力を validator で検証してから保存する。
func (a *API) create(w http.ResponseWriter, r *http.Request) {
	var req createExpenseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
		return
	}
	if err := a.validate.Struct(req); err != nil {
		writeJSON(w, http.StatusUnprocessableEntity, map[string]string{"error": err.Error()})
		return
	}
	created := a.store.Add(Expense{Amount: req.Amount, Memo: req.Memo, Category: req.Category})
	a.log.Info().Str("id", created.ID).Int64("amount", created.Amount).Str("category", created.Category).Msg("expense created")
	writeJSON(w, http.StatusCreated, created)
}

// get は ID で1件返す。
func (a *API) get(w http.ResponseWriter, r *http.Request) {
	e, ok := a.store.Get(chi.URLParam(r, "id"))
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	writeJSON(w, http.StatusOK, e)
}

// summary はダッシュボード用の集計を返す。
func (a *API) summary(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, a.store.Summary())
}
