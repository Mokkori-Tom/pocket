package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const showLast = 10

// memoPath は POCKET_MEMO があればそれを、なければ Android の共有ストレージ
// （termux-setup-storage 済みなら ~/storage/shared/Documents）を、それもなければ ~ を使う。
func memoPath() string {
	if p := os.Getenv("POCKET_MEMO"); p != "" {
		return p
	}
	home, _ := os.UserHomeDir()
	docs := filepath.Join(home, "storage", "shared", "Documents")
	if fi, err := os.Stat(docs); err == nil && fi.IsDir() {
		return filepath.Join(docs, "pocket-memo.md")
	}
	return filepath.Join(home, "pocket-memo.md")
}

// runMemo は text が空なら最近のメモを返し、そうでなければ日時つきで追記する。
func runMemo(text string) (string, error) {
	path := memoPath()
	text = strings.TrimSpace(text)
	if text == "" {
		return tail(path, showLast)
	}

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return "", err
	}
	defer f.Close()
	line := fmt.Sprintf("- %s %s\n", time.Now().In(jst).Format("2006-01-02 15:04"), strings.ReplaceAll(text, "\n", " "))
	if _, err := f.WriteString(line); err != nil {
		return "", err
	}
	return "メモしました: " + text, nil
}

func tail(path string, n int) (string, error) {
	f, err := os.Open(path)
	if os.IsNotExist(err) {
		return "（メモはまだありません）", nil
	}
	if err != nil {
		return "", err
	}
	defer f.Close()

	var lines []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return strings.Join(lines, "\n"), sc.Err()
}
