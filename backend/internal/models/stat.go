package models

type Stat struct {
	UserID       string `json:"user_id"`
	TotalRuns    int    `json:"total_runs"`
	BestScore    int    `json:"best_score"`
	BestLevel    int    `json:"best_level"`
	TotalTime    int    `json:"total_time"`
	TotalKills   int    `json:"total_kills"`
}
