package api

// API specification
#Endpoint: {
	path:   string
	method: "GET" | "POST" | "PUT" | "DELETE"
	description?: string
}

#Service: {
	name:      string
	version:   string
	endpoints: [...#Endpoint]
}

service: #Service

