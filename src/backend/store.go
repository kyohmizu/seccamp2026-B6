package main

import (
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Expense は経費1件。ID はサーバ側で UUID を採番する。
type Expense struct {
	ID        string    `json:"id"`
	Amount    int64     `json:"amount"`
	Memo      string    `json:"memo"`
	Category  string    `json:"category"`
	CreatedAt time.Time `json:"createdAt"`
}

// CategorySummary はカテゴリ別の集計。
type CategorySummary struct {
	Category string `json:"category"`
	Total    int64  `json:"total"`
	Count    int    `json:"count"`
}

// Summary はダッシュボード用の集計値。
type Summary struct {
	Total      int64             `json:"total"`
	MonthTotal int64             `json:"monthTotal"`
	Count      int               `json:"count"`
	ByCategory []CategorySummary `json:"byCategory"`
}

// Filter は一覧の絞り込み条件。ゼロ値は「条件なし」。
type Filter struct {
	Category string
	From     time.Time
	To       time.Time
}

// Store は経費のインメモリ保管庫（再起動で消える）。
type Store struct {
	mu    sync.RWMutex
	items []Expense
}

func NewStore() *Store { return &Store{} }

// Add は1件追加する。ID・カテゴリ既定値・登録日時をサーバ側で補う。
func (s *Store) Add(e Expense) Expense {
	s.mu.Lock()
	defer s.mu.Unlock()
	if e.Category == "" {
		e.Category = "その他"
	}
	if e.CreatedAt.IsZero() {
		e.CreatedAt = time.Now().UTC()
	}
	e.ID = uuid.NewString()
	s.items = append(s.items, e)
	return e
}

// List は条件で絞り込み、新しい順に返す。
func (s *Store) List(f Filter) []Expense {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Expense, 0, len(s.items))
	for _, e := range s.items {
		if f.Category != "" && e.Category != f.Category {
			continue
		}
		if !f.From.IsZero() && e.CreatedAt.Before(f.From) {
			continue
		}
		if !f.To.IsZero() && e.CreatedAt.After(f.To) {
			continue
		}
		out = append(out, e)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out
}

// Get は ID で1件返す。
func (s *Store) Get(id string) (Expense, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, e := range s.items {
		if e.ID == id {
			return e, true
		}
	}
	return Expense{}, false
}

// Summary は合計・当月合計・件数・カテゴリ別内訳を返す。
func (s *Store) Summary() Summary {
	s.mu.RLock()
	defer s.mu.RUnlock()
	// 「今月」は日本時間で判定する。distroless イメージには tzdata が無いため
	// LoadLocation ではなく固定オフセット（JST=UTC+9、DST なし）を用いる。
	jst := time.FixedZone("JST", 9*60*60)
	now := time.Now().In(jst)
	sum := Summary{}
	byCat := map[string]*CategorySummary{}
	for _, e := range s.items {
		sum.Total += e.Amount
		sum.Count++
		created := e.CreatedAt.In(jst)
		if created.Year() == now.Year() && created.Month() == now.Month() {
			sum.MonthTotal += e.Amount
		}
		c, ok := byCat[e.Category]
		if !ok {
			c = &CategorySummary{Category: e.Category}
			byCat[e.Category] = c
		}
		c.Total += e.Amount
		c.Count++
	}
	for _, c := range byCat {
		sum.ByCategory = append(sum.ByCategory, *c)
	}
	sort.Slice(sum.ByCategory, func(i, j int) bool { return sum.ByCategory[i].Total > sum.ByCategory[j].Total })
	return sum
}

// Seed は初回表示が空にならないようサンプルを投入する。
func (s *Store) Seed() {
	now := time.Now().UTC()
	samples := []struct {
		amount   int64
		memo     string
		category string
		daysAgo  int
	}{
		{12000, "羽田-伊丹 出張往復", "交通費", 0},
		{3200, "チームランチ", "会議費", 1},
		{45800, "モニター・キーボード", "消耗品", 3},
		{8600, "取引先との会食", "接待費", 6},
		{1980, "技術書の購入", "その他", 9},
	}
	for _, sm := range samples {
		s.Add(Expense{Amount: sm.amount, Memo: sm.memo, Category: sm.category, CreatedAt: now.AddDate(0, 0, -sm.daysAgo)})
	}
}
