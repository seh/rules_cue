package contacts

import "strings"

// Contact represents a person's contact information
#Contact: {
	// Name of the person
	name: {
		first: strings.MinRunes(1)
		last:  strings.MinRunes(1)
	}
	// Email address
	email: =~"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
	// Phone number (optional)
	phone?: string
	// Age must be a positive integer
	age?: int & >0
	// Tags for categorizing contacts
	tags?: [...string]
}

// List of contacts must conform to the Contact schema
contacts: [...#Contact]

