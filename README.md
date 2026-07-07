# santoku-fs

Filesystem helpers for santoku: buffered/whole-file I/O, path string
manipulation, directory traversal, and a thin POSIX C extension
(`santoku.fs.posix`). Built on base `santoku` (errors, validation, string,
array). See [../lua-santoku/README.md](../lua-santoku/README.md) for those base
types.

This README is a usage guide, not an API reference. The tests are the spec:
`test/spec/santoku/fs.lua` exercises the full surface. Read it for the exhaustive
function list; read this for how the pieces fit.

## Conventions

- **`santoku.fs` re-exports `santoku.fs.posix` and stock `io`.** `require("santoku.fs")`
  gives you the high-level helpers plus the POSIX primitives (`cwd`, `cd`,
  `mkdir`, `mode`, `touch`, `hardlink`, `symlink`, ...) and the `io` table merged
  in. Reach for the high-level helper first; the POSIX call is there when you need it.
- **Structured errors, not nil returns.** Wrappers raise through `santoku.error`
  on failure (carrying the OS message and errno), so call sites use `pcall` rather
  than checking `nil`. The predicate helpers (`exists`, `isfile`, `isdir`) return
  `false` for a missing path and re-raise any other error.
- **Iterators for traversal.** `dir`, `walk`, `files`, `dirs`, `chunks`,
  `splitparts`, `splitexts` return Lua iterators; drive them with `for` or collect
  with `santoku.array.icollect`.
- **Paths are plain strings.** Path manipulation (`join`, `dirname`, `basename`,
  `extension`, `stripparts`, ...) is string work, no stat calls.

## Whole-file I/O

```lua
local fs = require("santoku.fs")

fs.writefile("out.txt", "hello")     -- truncating write (pass a flag for append)
fs.readfile("out.txt")               -- "hello"

-- with: open, run fn(handle), always close (even on error); returns fn's results
fs.with("out.txt", "r", function (fh)
  return fs.read(fh, "*all")
end)

local f = fs.loadfile("script.lua")  -- compile a Lua file to a function
fs.runfile("script.lua")             -- load + call (globals visible by default)
```

## Chunked reading

`chunks` streams a file in fixed-size pieces, optionally splitting on delimiter
bytes. It yields `chunk, start, end` index triples into the current buffer, so you
slice without copying:

```lua
for chunk, s, e in fs.chunks("big.txt", "\n", 4096) do
  local line = chunk:sub(s, e)
  -- ...
end
```

With no delimiter it yields raw fixed-size blocks. A line longer than the chunk
size raises `"chunk doesn't fit"`.

## Directory traversal

```lua
for name, mode in fs.files("src", true) do ... end   -- recurse = true
for name in fs.dirs("src", true) do ... end          -- directories only
for name, mode in fs.walk("src", prune, leaves) do ... end

fs.mkdirp("a/b/c")        -- mkdir -p
fs.rmdirs("a")            -- remove a directory tree (empties depth-first)
fs.rm("f", true)          -- remove a file; 2nd arg tolerates ENOENT
```

`walk` is the primitive; `files` and `dirs` are filters over it. `prune(name, mode)`
returns truthy to skip a directory, or `"keep"` to yield it without descending.

## Path strings

```lua
fs.join("a/", "b")                  -- "a/b"  (collapses separators)
fs.dirname("/opt/bin/sort")         -- "/opt/bin"
fs.basename("/opt/bin/sort")        -- "sort"
fs.extensions("x.tar.gz")           -- ".tar.gz"   (extension -> ".gz")
fs.stripextensions("x.tar.gz")      -- "x"
fs.stripparts("/home/u/a/b.txt", 2) -- "a/b.txt"   (drop n leading components)
```

## POSIX extension (`santoku.fs.posix`)

The C layer is normally reached through `santoku.fs`. Directly it exposes
`cwd`/`cd`, `mkdir`/`rmdir`, `mode` (stat to a type string), `touch`, `hardlink`,
`symlink`, `absolute` (realpath, tolerating a non-existent tail), the directory
cursor (`diropen`/`dirent`/`dirclose`), `next_chunk`, and `tmpfile`.

## Covers

`test/spec/santoku/fs.lua` (path manipulation, traversal, queries, hardlink/symlink)
and `test/spec/santoku/fsio.lua` (whole-file I/O, `with`, `loadfile`/`runfile`,
`pushd`, `mv`, `touch`). Run them through the `toku` harness so the C extension is
built and on the path.

## License

MIT License

Copyright 2025 Birch Point SWE

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
