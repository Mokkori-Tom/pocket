package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDecode(t *testing.T) {
	cases := []struct {
		in, kind, contains string
	}{
		{"1700000000", "UNIX時刻", "2023-11-15 07:13:20 JST"},
		{"1700000000000", "UNIX時刻", "2023-11-15 07:13:20 JST"},
		{`{"a":1,"b":[true]}`, "JSON", "\n  \"a\": 1,"},
		{"44GT44KT44Gr44Gh44Gv", "Base64", "こんにちは"},
		{"aGVsbG8gd29ybGQ=", "Base64", "hello world"},
		{"%E6%9D%B1%E4%BA%AC%20tower", "URLエンコード", "東京 tower"},
		{"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0dWEiLCJpYXQiOjE3MDAwMDAwMDB9.sig", "JWT", `"sub": "tua"`},
	}
	for _, c := range cases {
		kind, out, ok := decode(c.in)
		if !ok || kind != c.kind || !strings.Contains(out, c.contains) {
			t.Errorf("decode(%q) = %q, %q, %v; want kind %q containing %q", c.in, kind, out, ok, c.kind, c.contains)
		}
	}
	for _, in := range []string{"hello", "ただの日本語", "abcd"} {
		if kind, _, ok := decode(in); ok {
			t.Errorf("decode(%q) should fail, got kind %q", in, kind)
		}
	}
}

func TestLink(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/og":
			w.Write([]byte(`<html><head><meta property="og:title" content="OG &amp; タイトル"><title>使われない</title></head></html>`))
		case "/plain":
			w.Write([]byte("<title>\n  Go [公式]  \n</title>"))
		default:
			w.Write([]byte("<p>no title</p>"))
		}
	}))
	defer srv.Close()

	cases := []struct{ in, want string }{
		{srv.URL + "/og", "[OG & タイトル](" + srv.URL + "/og)"},
		{"見てこれ " + srv.URL + "/plain", `[Go \[公式\]](` + srv.URL + "/plain)"},
		{srv.URL + "/none", "[" + strings.TrimPrefix(srv.URL, "http://") + "](" + srv.URL + "/none)"},
	}
	for _, c := range cases {
		got, err := runLink(c.in)
		if err != nil || got != c.want {
			t.Errorf("runLink(%q) = %q, %v; want %q", c.in, got, err, c.want)
		}
	}
	if _, err := runLink("URLなし"); err == nil {
		t.Error("runLink without URL should fail")
	}
}

func TestMemo(t *testing.T) {
	path := filepath.Join(t.TempDir(), "memo.md")
	t.Setenv("POCKET_MEMO", path)

	if out, _ := runMemo(""); !strings.Contains(out, "まだありません") {
		t.Errorf("empty memo: %q", out)
	}
	for i := 0; i < 12; i++ {
		if _, err := runMemo("牛乳を買う\n" + string(rune('A'+i))); err != nil {
			t.Fatal(err)
		}
	}
	b, _ := os.ReadFile(path)
	if n := strings.Count(string(b), "\n"); n != 12 {
		t.Errorf("memo file has %d lines, want 12", n)
	}
	out, _ := runMemo("")
	if lines := strings.Split(out, "\n"); len(lines) != showLast || !strings.HasSuffix(lines[len(lines)-1], "牛乳を買う L") {
		t.Errorf("tail = %q", out)
	}
}
