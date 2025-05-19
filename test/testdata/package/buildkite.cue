package language

import "cue.dev/x/buildkite@v0"

pipeline: buildkite.#Pipeline & {
	steps: []
}
