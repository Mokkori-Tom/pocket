// pocket は Termux のホーム画面ショートカットから呼ぶ小さな道具箱。
package main

import (
	"fmt"
	"io"
	"os"
	"strings"
)

const usage = `使い方: pocket <コマンド> [引数]

  link <URL>     ページのタイトルを取ってきて Markdown リンクにする
  decode [文字列] JSON / Base64 / URLエンコード / UNIX時刻 / JWT を自動判別して読める形にする
  memo [文字列]   日時つきでメモに追記する（引数なしなら最近のメモを表示）

文字列を省略すると標準入力から読みます。
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	cmd, args := os.Args[1], os.Args[2:]

	var out string
	var err error
	switch cmd {
	case "link":
		out, err = runLink(argOrStdin(args))
	case "decode":
		out, err = runDecode(argOrStdin(args))
	case "memo":
		out, err = runMemo(strings.Join(args, " "))
	case "-h", "--help", "help":
		fmt.Print(usage)
		return
	default:
		fmt.Fprintf(os.Stderr, "不明なコマンド: %s\n\n%s", cmd, usage)
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "エラー:", err)
		os.Exit(1)
	}
	fmt.Println(out)
}

// argOrStdin は引数があれば連結して返し、なければ標準入力を読む。
func argOrStdin(args []string) string {
	if len(args) > 0 {
		return strings.Join(args, " ")
	}
	if fi, err := os.Stdin.Stat(); err == nil && fi.Mode()&os.ModeCharDevice != 0 {
		return ""
	}
	b, _ := io.ReadAll(os.Stdin)
	return string(b)
}
