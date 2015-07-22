package main

/*
 * Copyright 2015 Albert P. Tobey <atobey@datastax.com> @AlTobey
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Pull entrypoint-specific options out of the os.Args
 * so the rest can be passed through to backing tools.
 */

import (
	"log"
	"strconv"
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

// extractArg finds the named argument in args, removes it and its optional value
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
				// empty string default means it's a boolean flag
				if def != "" {
					args, argval = deleteArg(args, i)
				}
			}
		}
	}

	return args, argname, argval
}

// extractIntArg wraps extractArg and returns an integer value
// if the value provided cannot be converted to an integer, a fatal error is logged
func extractIntArg(args []string, want string, def int) ([]string, string, int) {
	args_out, argname, argval := extractArg(args, want, strconv.Itoa(def))
	argint, err := strconv.Atoi(argval)
	if err != nil {
		log.Fatalf("Failed to convert argument '%s' value of '%s' to an integer: %s\n", argname, argval, err)
	}
	return args_out, argname, argint
}
