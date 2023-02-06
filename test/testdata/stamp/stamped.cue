import (
	"strings"
	"time"
)

_builtAtSecondsSinceEpoch: int @tag(builtat,type=int)
_builtAt:                  time.Unix(_builtAtSecondsSinceEpoch, 0)
// Emit something stable that we can check in unit tests at any time.  CUE's time.Unix uses RFC 3339
// format which guarantees a fixed width so long as the time is captured in UTC.
builtAtWidth: len(strings.Runes(_builtAt))
// In order to allow tests to pass when run by various users, don't actually emit the value injected
// for the "BUILD_USER" placeholder here. Instead, just mandate that some nonempty value makes it in
// by way of injection.
_builtBy:         string | *"" @tag(builtby)
builtByPopulated: len(_builtBy) > 0
message:          string | *"Hello." @tag(message)
