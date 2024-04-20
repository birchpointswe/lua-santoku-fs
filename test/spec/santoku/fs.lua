local test = require("santoku.test")
local serialize = require("santoku.serialize") -- luacheck: ignore

local err = require("santoku.error")
local assert = err.assert
local pcall = err.pcall

local arr = require("santoku.array")
local apack = arr.pack
local apush = arr.push
local asort = arr.sort

local validate = require("santoku.validate")
local eq = validate.isequal
local isnil = validate.isnil

local tbl = require("santoku.table")
local teq = tbl.equals

local fs = require("santoku.fs")
local fopen = fs.open

local iter = require("santoku.iter")
local icollect = iter.collect
local imap = iter.map

local str = require("santoku.string")
local ssub = str.sub
local scmp = str.compare

test("chunk basic", function ()
  assert(teq({ "line 1\nl", "ine 2\nli", "ne 3\nlin", "e 4\n" },
    icollect(fs.chunks(fopen("test/res/fs.tst1.txt"), nil, 8))))
end)

test("chunk delims", function ()
  local expected =
    { { "line 1\nline 2\nli", 1, 7 },
      { "line 1\nline 2\nli", 8, 14 },
      { "line 3\nline 4\n", 1, 7 },
      { "line 3\nline 4\n", 8, 14 }, }
  local actual = icollect(imap(apack, fs.chunks(fopen("test/res/fs.tst1.txt"), "\n", 16)))
  assert(teq(expected, actual))
end)

test("chunk delim doesnt fit", function ()
  assert(teq({ false, "chunk doesn't fit", 0, 5},
    { pcall(icollect, fs.chunks(fopen("test/res/fs.tst1.txt"), "\n", 5)) }))
end)

test("join", function ()
  assert(eq("a/b", fs.join("a/", "b")))
end)

test("dirname", function ()
  assert(eq("/opt/bin", fs.dirname("/opt/bin/sort")))
  assert(eq(".", fs.dirname("stdio.h")))
  assert(eq("../..", fs.dirname("../../test")))
end)

test("basename", function ()
  assert(eq("sort", fs.basename("/opt/bin/sort")))
  assert(eq("stdio.h", fs.basename("stdio.h")))
  assert(isnil(fs.basename("/home/user/")))
end)








test("extension", function ()
  assert(eq(".tar.gz", fs.extensions("something.tar.gz")))
  assert(eq(".gz", fs.extension("something.tar.gz")))
  assert(eq(".tar.gz", fs.extension("something.tar.gz", true)))
  assert(isnil(fs.extensions("something")))
  assert(isnil(fs.extension("something")))
end)

test("stripextension", function ()
  assert(eq("something.tar", fs.stripextension("something.tar.gz")))
  assert(eq("something", fs.stripextensions("something.tar.gz")))
  assert(eq("something", fs.stripextension("something")))
end)

test("splitexts", function ()
  assert(teq({ "tar", "gz"},
    icollect(imap(ssub, fs.splitexts("/this/test.tar.gz")))))
  assert(teq({ ".tar", ".gz"},
    icollect(imap(ssub, fs.splitexts("/this/test.tar.gz", true)))))
end)

test("splitparts", function ()
  assert(teq({ "this", "is", "a", "test" },
    icollect(imap(ssub, fs.splitparts("/this//is/a/test//")))))
  assert(teq({ "/this", "//is", "/a", "/test", "//"},
    icollect(imap(ssub, fs.splitparts("/this//is/a/test//", "right")))))
  assert(teq({ "this", "//is", "/a", "/test", "//" },
    icollect(imap(ssub, fs.splitparts("this//is/a/test//", "right")))))
  assert(teq({ "/", "this//", "is/", "a/", "test//" },
    icollect(imap(ssub, fs.splitparts("/this//is/a/test//", "left")))))
  assert(teq({ "this//", "is/", "a/", "test//" },
    icollect(imap(ssub, fs.splitparts("this//is/a/test//", "left")))))
end)

test("stripparts", function ()
  assert(eq("a/b/c.txt", fs.stripparts("/home/user/a/b/c.txt", 2)))
  assert(eq("c.txt", fs.stripparts("/home/user/a/b/c.txt", 4)))
  assert(eq("/home/user/a/b/c.txt", fs.stripparts("/home/user/a/b/c.txt", 0)))
  assert(isnil(fs.stripparts("/home/user/a/b/c.txt", 5)))
  assert(isnil(fs.stripparts("/home/user/a/b/c.txt", 10)))
end)

test("diropen/dirent/dirclose", function ()
  local ents = {}
  local d = fs.diropen("test/res")
  while true do
    local f, m = fs.dirent(d)
    if not f then
      break
    end
    apush(ents, { f, m })
  end
  asort(ents, function (a, b)
    return str.compare(a[1], b[1])
  end)
  assert(teq(ents, {
    { ".", "directory" },
    { "..", "directory" },
    { "fs", "directory" },
    { "fs.tst1.txt", "file" },
    { "fs.tst2.txt", "file" },
    { "fs.tst3.txt", "file" },
  }))
  fs.dirclose(d)
end)

test("dir", function ()
  assert(teq({ ".", "..", "fs", "fs.tst1.txt", "fs.tst2.txt", "fs.tst3.txt" },
    asort(icollect(fs.dir("test/res")))))
end)

test("walk", function ()
  assert(teq(asort(icollect(imap(apack, fs.walk("test/res"))), function (a, b)
    return scmp(a[1], b[1])
  end), {
    { "test/res/fs", "directory" },
    { "test/res/fs/a", "directory" },
    { "test/res/fs/b", "directory" },
    { "test/res/fs/a/a.txt", "file" },
    { "test/res/fs/a/b.txt", "file" },
    { "test/res/fs/b/a.txt", "file" },
    { "test/res/fs/b/b.txt", "file" },
    { "test/res/fs.tst1.txt", "file" },
    { "test/res/fs.tst2.txt", "file" },
    { "test/res/fs.tst3.txt", "file" },
  }))
end)

test("files", function ()
  assert(teq(asort(icollect(fs.files("test/res", true)), scmp), {
    "test/res/fs/a/a.txt",
    "test/res/fs/a/b.txt",
    "test/res/fs/b/a.txt",
    "test/res/fs/b/b.txt",
    "test/res/fs.tst1.txt",
    "test/res/fs.tst2.txt",
    "test/res/fs.tst3.txt",
  }))
  assert(teq(asort(icollect(fs.files("test/res", false)), scmp), {
    "test/res/fs.tst1.txt",
    "test/res/fs.tst2.txt",
    "test/res/fs.tst3.txt",
  }))
end)

test("dirs", function ()
  assert(teq(icollect(fs.dirs("test/res", true)), {
    "test/res/fs",
    "test/res/fs/a",
    "test/res/fs/b",
  }))
  assert(teq(icollect(fs.dirs("test/res", false)), {
    "test/res/fs",
  }))
end)

test("exists", function ()
  assert(teq({ true, "directory" }, { fs.exists("test/spec") } ))
  assert(teq({ false }, { fs.exists("test/spec__doesntexist") } ))
end)

test("isdir", function ()
  assert(teq({ true }, { fs.isdir("test/spec") }))
  assert(teq({ false }, { fs.isdir("test/spec-doesnt-exist") }))
  assert(teq({ false }, { fs.isdir("run.sh") }))
end)

test("isfile", function ()
  assert(teq({ false }, { fs.isfile("test/spec") }))
  assert(teq({ false }, { fs.isfile("test/spec-doesnt-exist") }))
  assert(teq({ true }, { fs.isfile("run.sh") }))
end)















