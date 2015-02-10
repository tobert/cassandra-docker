package main

// pull entrypoint-specific options out of the os.Args
// so the rest can be passed through to backing tools

import (
	"strings"
)

func deleteArg(args []string, index int) ([]string, string) {
	var deleted string
	out := make([]string, len(args)-1)

	offset := 0
	for i := range args {
		if i == index {
			deleted = args[i]
			offset = 1
			continue
		}
		out[i-offset] = args[i]
	}

	return out, deleted
}

// findArg finds the named argument in args, removes it and its optional value
// from args then returns the modified list, the provided arg, and its value. If the
// default value is empty string, the arg is assumed to be a boolean switch with no value.
// e.g. leftover, results := extractArg(os.Args[1:], "seeds", "127.0.0.1")
func extractArg(args []string, want string, def string) ([]string, string, string) {
	argname := "" // gets replaced with the user-provided string (e.g. --seeds, -seeds)
	argval := def // gets replaced with the provided value only when present

	for i, arg := range args {
		if strings.HasPrefix(arg, "-") {
			// remove 1 or more dashes so --seeds and -seeds are both supported
			if strings.TrimLeft(arg, "-") == want {
				args, argname = deleteArg(args, i)
				if def != "" {
					args, argval = deleteArg(args, i)
				}
			}
		}
	}

	return args, argname, argval
}
