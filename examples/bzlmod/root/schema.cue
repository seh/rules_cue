package contacts

import (
	"strings"
)

#Entry: {
	name: {
		common: strings.MinRunes(1)
		// Not all people have a middle name.
		middle?: strings.MinRunes(1)
		// Accommodate mononymous people.
		surname?: strings.MinRunes(1)
	}
	birth: {
		month: "January" |
			"February" |
			"March" |
			"April" |
			"May" |
			"June" |
			"July" |
			"August" |
			"September" |
			"October" |
			"November" |
			"December"
		year: int
	}
}

entries: [...#Entry]
extra_entries: [...#Entry]
