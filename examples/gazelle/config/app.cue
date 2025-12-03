package config

#AppConfig: {
	app: {
		name:    string
		version: string
		port:    int & >0 & <65536
	}
	database: {
		host:     string
		port:     int & >0 & <65536
		name:     string
		user:     string
		password: string
	}
	logging: {
		level:  "debug" | "info" | "warn" | "error"
		format: "json" | "text"
	}
}

config: #AppConfig

