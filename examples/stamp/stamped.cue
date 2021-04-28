import "time"

_builtAtSecondsSinceEpoch: int @tag(builtat,type=int)
builtAt:                   time.Unix(_builtAtSecondsSinceEpoch, 0)
builtBy:                   string | *"unknown" @tag(builtby)
message:                   string | *"Hello."  @tag(message)
