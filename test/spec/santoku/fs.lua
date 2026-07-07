local test = require("santoku.test")
local serialize = require("santoku.serialize") -- luacheck: ignore

local err = require("santoku.error")
local assert = err.assert
local pcall = err.pcall

local arr = require("santoku.array")
local apush = arr.push
local asort = arr.sort
local icollect = arr.icollect
local imap = arr.imap
local apack = arr.pack

local validate = require("santoku.validate")
local eq = validate.isequal
local isnil = validate.isnil

local tbl = require("santoku.table")
local teq = tbl.equals

local fs = require("santoku.fs")
local fopen = fs.open

local str = require("santoku.string")
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
  local actual = imap(apack, fs.chunks(fopen("test/res/fs.tst1.txt"), "\n", 16))
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
    icollect(fs.splitexts("/this/test.tar.gz"))))
  assert(teq({ ".tar", ".gz"},
    icollect(fs.splitexts("/this/test.tar.gz", true))))
end)

test("splitparts", function ()
  assert(teq({ "this", "is", "a", "test" },
    icollect(fs.splitparts("/this//is/a/test//"))))
  assert(teq({ "/this", "//is", "/a", "/test" },
    icollect(fs.splitparts("/this//is/a/test//", "right"))))
  assert(teq({ "this", "//is", "/a", "/test" },
    icollect(fs.splitparts("this//is/a/test//", "right"))))
  assert(teq({ "/", "this//", "is/", "a/", "test//" },
    icollect(fs.splitparts("/this//is/a/test//", "left"))))
  assert(teq({ "this//", "is/", "a/", "test//" },
    icollect(fs.splitparts("this//is/a/test//", "left"))))
end)

test("stripparts", function ()
  assert(eq("a/b/c.txt", fs.stripparts("/home/user/a/b/c.txt", 2)))
  assert(eq("c.txt", fs.stripparts("/home/user/a/b/c.txt", 4)))
  assert(eq("/home/user/a/b/c.txt", fs.stripparts("/home/user/a/b/c.txt", 0)))
  assert(isnil(fs.stripparts("/home/user/a/b/c.txt", 5)))
  assert(isnil(fs.stripparts("/home/user/a/b/c.txt", 10)))
end)

local function clean_tmp (dir)
  if not fs.exists(dir) then
    return
  end
  for fp, m in fs.walk(dir) do
    if m == "file" then
      fs.rm(fp, true)
    end
  end
  fs.rmdirs(dir)
end

local function make_tmp (dir)
  clean_tmp(dir)
  fs.mkdirp(dir .. "/sub")
  fs.writefile(dir .. "/a.txt", "a")
  fs.writefile(dir .. "/b.txt", "b")
end

test("diropen/dirent/dirclose", function ()
  local dir = "test/res/dirent"
  make_tmp(dir)
  local ents = {}
  local d = fs.diropen(dir)
  while true do
    local f, m = fs.dirent(d)
    if not f then
      break
    end
    if f ~= "." and f ~= ".." then
      apush(ents, { f, m })
    end
  end
  fs.dirclose(d)
  asort(ents, function (a, b)
    return a[1] < b[1]
  end)
  assert(teq(ents, {
    { "a.txt", "file" },
    { "b.txt", "file" },
    { "sub", "directory" },
  }))
  clean_tmp(dir)
end)

test("dir", function ()
  local dir = "test/res/dirlist"
  make_tmp(dir)
  local got = {}
  for _, f in ipairs(icollect(fs.dir(dir))) do
    if f ~= "." and f ~= ".." then
      apush(got, f)
    end
  end
  assert(teq({ "a.txt", "b.txt", "sub" }, asort(got)))
  clean_tmp(dir)
end)

test("walk", function ()
  assert(teq(asort(imap(apack, fs.walk("test/res")), function (a, b)
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

test("mkdirp", function ()
  local testdir = "test/res/mkdirp_test/nested/deep/path"
  if fs.exists("test/res/mkdirp_test") then
    fs.rmdirs("test/res/mkdirp_test")
  end
  fs.mkdirp(testdir)
  assert(fs.isdir(testdir))
  assert(fs.isdir("test/res/mkdirp_test/nested/deep"))
  assert(fs.isdir("test/res/mkdirp_test/nested"))
  assert(fs.isdir("test/res/mkdirp_test"))
  fs.rmdirs("test/res/mkdirp_test")
  assert(not fs.exists("test/res/mkdirp_test"))
end)



if fs.hardlink then
  test("hardlink", function ()
    local src = "test/res/hl_src.txt"
    local dst = "test/res/hl_dst.txt"
    fs.rm(src, true)
    fs.rm(dst, true)
    fs.writefile(src, "hello")
    local ok, _, code = pcall(fs.hardlink, src, dst)
    if not ok and (code == 1 or code == 13) then
      fs.rm(src, true)
      return
    end
    assert(ok)
    assert(fs.isfile(dst))
    assert(eq("hello", fs.readfile(dst)))
    fs.writefile(src, "changed")
    assert(eq("changed", fs.readfile(dst)))
    fs.rm(src)
    fs.rm(dst)
  end)
end

if fs.symlink then
  test("symlink", function ()
    local src = "test/res/sl_src.txt"
    local dst = "test/res/sl_dst.txt"
    fs.rm(src, true)
    fs.rm(dst, true)
    fs.writefile(src, "world")
    fs.symlink("sl_src.txt", dst)
    assert(eq("world", fs.readfile(dst)))
    fs.rm(dst)
    fs.symlink("sl_missing.txt", dst)
    assert(not fs.exists(dst))
    fs.rm(dst)
    fs.rm(src)
  end)
end















