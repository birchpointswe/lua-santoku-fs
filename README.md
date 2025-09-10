# Santoku FS

Filesystem operations module for Lua providing file I/O, directory traversal, path manipulation, and POSIX filesystem utilities.

## Module Reference

### `santoku.fs`

Comprehensive filesystem operations including file I/O, directory operations, and path manipulation.

#### File I/O Operations

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `open` | `file/path, [mode]` | `handle, was_open` | Opens file with mode (r/w/a/etc) |
| `close` | `handle, ...` | `...` | Closes file handle |
| `read` | `handle, ...` | `content` | Reads from file handle |
| `write` | `handle, ...` | `...` | Writes to file handle |
| `flush` | `handle, ...` | `...` | Flushes file handle buffer |
| `seek` | `handle, ...` | `position` | Sets/gets file position |
| `setvbuf` | `handle, ...` | `...` | Sets buffering mode |
| `with` | `path, mode, fn, ...` | `...` | Executes function with open file, auto-closes |
| `readfile` | `path, [mode]` | `string` | Reads entire file as string |
| `writefile` | `path, content, [mode]` | `-` | Writes string to file |
| `loadfile` | `path, [env]` | `function` | Loads Lua file as function |
| `runfile` | `path, [env], [no_globals]` | `...` | Loads and executes Lua file |

#### Path Manipulation

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `join` | `...paths` | `string` | Joins path components with separator |
| `dirname` | `path` | `string` | Returns directory portion of path |
| `basename` | `path` | `string/nil` | Returns filename portion of path |
| `extension` | `path, [all]` | `string/nil` | Returns file extension(s) |
| `extensions` | `path` | `string/nil` | Returns all file extensions |
| `stripextension` | `path, [all]` | `string` | Removes file extension(s) |
| `stripextensions` | `path` | `string` | Removes all file extensions |
| `splitparts` | `path, [delim]` | `iterator` | Splits path into components |
| `splitexts` | `path, [keep_dots]` | `iterator` | Splits extensions |
| `stripparts` | `path, n, [keep_sep]` | `string` | Removes n path components |

#### Directory Operations

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `dir` | `path` | `iterator` | Iterates directory entries |
| `walk` | `path, [prune], [leaves]` | `iterator` | Recursively walks directory tree |
| `files` | `path, [recurse]` | `iterator` | Iterates files only |
| `dirs` | `path, [recurse], [leaves]` | `iterator` | Iterates directories only |
| `mkdirp` | `path` | `-` | Creates directory and parents |
| `rm` | `path, [allow_noexist]` | `-` | Removes file or empty directory |
| `rmdirs` | `path` | `-` | Recursively removes empty directories |
| `mv` | `old, new` | `-` | Renames/moves file or directory |
| `pushd` | `path, fn, ...` | `...` | Changes directory, executes function, restores |

#### File System Queries

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `exists` | `path` | `boolean, [mode]` | Checks if path exists |
| `isfile` | `path` | `boolean` | Checks if path is regular file |
| `isdir` | `path` | `boolean` | Checks if path is directory |
| `tmpname` | `-` | `string` | Returns temporary filename |

#### Stream Operations

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `chunks` | `file/path, [delims], [size], [omit]` | `iterator` | Iterates file in chunks |
| `stdout` | `-` | `handle` | Standard output handle |
| `stderr` | `-` | `handle` | Standard error handle |
| `stdin` | `-` | `handle` | Standard input handle |

### `santoku.fs.posix`

Low-level POSIX filesystem operations.

| Function | Arguments | Returns | Description |
|----------|-----------|---------|-------------|
| `cd` | `path` | `-` | Changes current directory |
| `cwd` | `-` | `string` | Returns current working directory |
| `mkdir` | `path` | `-` | Creates directory |
| `rmdir` | `path` | `-` | Removes empty directory |
| `mode` | `path` | `string` | Returns file mode (file/directory/etc) |
| `diropen` | `path` | `handle` | Opens directory for reading |
| `dirent` | `handle` | `name, mode` | Reads next directory entry |
| `next_chunk` | `handle, delims, size, ...` | `chunk, ...` | Reads next chunk from file |
| `ENOENT` | `-` | `number` | File not found error code |
| `EEXIST` | `-` | `number` | File exists error code |

## License

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