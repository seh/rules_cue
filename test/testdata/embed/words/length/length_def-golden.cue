package words

import "other-example.com/text"

_favoriteWords: [...string] & {
	["dog", "moose"]
} @embed(file=favorite-words.json)
description: "Count of constituent letters in each of our favorite words\n" @embed(file=description.txt)
favoriteWordsLetterCounts: {
	for w in _favoriteWords {
		(w): text.counts[w]
	}
}
