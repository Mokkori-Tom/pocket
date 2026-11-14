package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

var (
	reUnix    = regexp.MustCompile(`^\d{10}(\d{3})?$`)
	reJWT     = regexp.MustCompile(`^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$`)
	reURLEnc  = regexp.MustCompile(`%[0-9A-Fa-f]{2}`)
	reBase64  = regexp.MustCompile(`^[A-Za-z0-9+/_-]+={0,2}$`)
	jst       = time.FixedZone("JST", 9*60*60)
	errNoKind = errors.New("判別できませんでした（JSON / Base64 / URLエンコード / UNIX時刻 / JWT に対応）")
)

// runDecode は入力の種類を自動判別し、「種別」行と変換結果を返す。
func runDecode(in string) (string, error) {
	s := strings.TrimSpace(in)
	if s == "" {
		return "", errors.New("入力が空です")
	}
	kind, out, ok := decode(s)
	if !ok {
		return "", errNoKind
	}
	return kind + "\n" + out, nil
}

func decode(s string) (kind, out string, ok bool) {
	// 判別の順番に意味がある: 数字だけの文字列は Base64 としても読めてしまうので先に時刻を見る
	if reUnix.MatchString(s) {
		n, _ := strconv.ParseInt(s, 10, 64)
		var t time.Time
		if len(s) == 13 {
			t = time.UnixMilli(n)
		} else {
			t = time.Unix(n, 0)
		}
		return "UNIX時刻", t.In(jst).Format("2006-01-02 15:04:05 MST (Mon)"), true
	}
	if json.Valid([]byte(s)) && (s[0] == '{' || s[0] == '[') {
		var buf bytes.Buffer
		json.Indent(&buf, []byte(s), "", "  ")
		return "JSON", buf.String(), true
	}
	if reJWT.MatchString(s) {
		parts := strings.Split(s, ".")
		h, err1 := b64(parts[0])
		p, err2 := b64(parts[1])
		if err1 == nil && err2 == nil && json.Valid(h) && json.Valid(p) {
			var buf bytes.Buffer
			json.Indent(&buf, p, "", "  ")
			return "JWT", "header: " + string(h) + "\npayload:\n" + buf.String(), true
		}
	}
	if reURLEnc.MatchString(s) {
		if d, err := url.QueryUnescape(s); err == nil && d != s {
			return "URLエンコード", d, true
		}
	}
	if len(s) >= 4 && reBase64.MatchString(s) {
		if d, err := b64(s); err == nil && readable(d) {
			return "Base64", string(d), true
		}
	}
	return "", "", false
}

// b64 は標準・URL セーフ、パディングあり・なしのどれでも受け付ける。
func b64(s string) ([]byte, error) {
	s = strings.TrimRight(s, "=")
	if strings.ContainsAny(s, "-_") {
		return base64.RawURLEncoding.DecodeString(s)
	}
	return base64.RawStdEncoding.DecodeString(s)
}

// readable はデコード結果が人間の読める UTF-8 テキストかを判定する。
// ただの英単語が偶然 Base64 として通るのを防ぐため、制御文字が混ざれば不可とする。
func readable(b []byte) bool {
	if len(b) == 0 || !utf8.Valid(b) {
		return false
	}
	for _, r := range string(b) {
		if unicode.IsControl(r) && r != '\n' && r != '\r' && r != '\t' {
			return false
		}
	}
	return true
}
