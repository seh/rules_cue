import (
	"strings"
	"time"
)

_builtAtSecondsSinceEpoch: int @tag(builtat,type=int)
_builtAt:                  time.Unix(_builtAtSecondsSinceEpoch, 0)
// Emit something stable that we can check in unit tests at any time.
// CUE's time.Unix uses RFC 3339 format which guarantees a fixed width
// so long as the time is captured in UTC.
builtAtWidth: len(strings.Runes(_builtAt))
builtBy:      string | *"unknown" @tag(builtby)
message:      string | *"Hello."  @tag(message)
