package api

service: {
	name:    "user-service"
	version: "v1.0.0"
	endpoints: [
		{
			path:        "/users"
			method:      "GET"
			description: "List all users"
		},
		{
			path:        "/users/{id}"
			method:      "GET"
			description: "Get a user by ID"
		},
		{
			path:        "/users"
			method:      "POST"
			description: "Create a new user"
		},
	]
}

