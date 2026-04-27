package words

import "other-example.com/text"

favoriteWordsLetterCounts: {
	for w in _favoriteWords {
		(w): text.counts[w]
	}
}
