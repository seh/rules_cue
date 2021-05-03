package greeting

import (
	"strings"

	"other-example.com/translations/en:es"
)

let native_word = "hello"
greeting: "\(strings.ToTitle(native_word)) or, if you prefer, \(es[native_word])!"
