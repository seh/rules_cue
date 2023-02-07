package color

import (
	"math"
)

[!=""]: {
	rgb8: >=0 & <math.Pow(2, 3*8)
}

blue: rgb8:  0x0000FF
green: rgb8: 0x00FF00
red: rgb8:   0xFF0000
