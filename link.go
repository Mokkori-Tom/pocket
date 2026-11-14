package main

import (
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

var (
	reOGTitle = regexp.MustCompile(`(?is)<meta[^>]+property=["']og:title["'][^>]*>`)
	reContent = regexp.MustCompile(`(?is)content=["']([^"']*)["']`)
	reTitle   = regexp.MustCompile(`(?is)<title[^>]*>(.*?)</title>`)
	reURL     = regexp.MustCompile(`https?://\S+`)
)

// runLink は URL のページタイトルを取得し、Markdown リンクを返す。
// 共有メニューから来る文字列は「タイトル URL」の形のこともあるので、URL 部分を拾う。
func runLink(in string) (string, error) {
	raw := reURL.FindString(strings.TrimSpace(in))
	if raw == "" {
		return "", errors.New("URL が見つかりません")
	}
	u, err := url.Parse(raw)
	if err != nil {
		return "", err
	}

	client := &http.Client{Timeout: 10 * time.Second}
	req, _ := http.NewRequest("GET", u.String(), nil)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Linux; Android) pocket")
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))

	title := extractTitle(string(body))
	if title == "" {
		title = u.Host
	}
	return fmt.Sprintf("[%s](%s)", title, u.String()), nil
}

// extractTitle は og:title を優先し、なければ <title> を使う。
func extractTitle(doc string) string {
	if tag := reOGTitle.FindString(doc); tag != "" {
		if m := reContent.FindStringSubmatch(tag); m != nil {
			if t := cleanTitle(m[1]); t != "" {
				return t
			}
		}
	}
	if m := reTitle.FindStringSubmatch(doc); m != nil {
		return cleanTitle(m[1])
	}
	return ""
}

func cleanTitle(s string) string {
	s = html.UnescapeString(s)
	s = strings.Join(strings.Fields(s), " ")
	// Markdown のリンク表記を壊す角括弧はエスケープする
	return strings.NewReplacer("[", `\[`, "]", `\]`).Replace(s)
}
