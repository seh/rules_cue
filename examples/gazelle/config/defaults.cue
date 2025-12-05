package config

config: {
	app: {
		name:    "example-app"
		version: "1.0.0"
		port:    8080
	}
	database: {
		host:     "localhost"
		port:     5432
		name:     "mydb"
		user:     "dbuser"
		password: "changeme"
	}
	logging: {
		level:  "info"
		format: "json"
	}
}

