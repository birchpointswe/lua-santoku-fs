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
local acat = arr.concat

local validate = require("santoku.validate")
local eq = validate.isequal
local isnil = validate.isnil

local tbl = require("santoku.table")
local teq = tbl.equals

local fs = require("santoku.fs")
local fopen = fs.open

local str = require("santoku.string")
local scmp = str.compare
local ssub = str.sub
local smatches = str.matches

local function clean_tmp (dir)
  if not fs.exists(dir) then
    return
  end
  for fp, m in fs.walk(dir) do
    if m ~= "directory" then
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

local function write_chunk_tmp (content)
  local dir = "test/tmp/chunks"
  clean_tmp(dir)
  fs.mkdirp(dir)
  local fp = dir .. "/data.txt"
  fs.writefile(fp, content)
  return fp
end

local function segments (content, delims, size)
  local fp = write_chunk_tmp(content)
  local out = {}
  for chunk, s, e in fs.chunks(fp, delims, size, true) do
    apush(out, ssub(chunk, s, e))
  end
  clean_tmp("test/tmp")
  return out
end

local function blocks (content, size)
  local fp = write_chunk_tmp(content)
  local out = icollect(fs.chunks(fp, nil, size))
  clean_tmp("test/tmp")
  return out
end

local function repeated (n, s)
  local t = {}
  for i = 1, n do
    t[i] = s
  end
  return acat(t, "")
end

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

test("chunk delim landing on the buffer boundary", function ()
  assert(teq({ "abc", "def", "ghi" }, segments("abc\ndef\nghi\n", "\n", 8)))
  assert(teq({ "abc", "def" }, segments("abc\ndef\n", "\n", 4)))
  assert(teq({ "abc", "def", "ghi" }, segments("abc\ndef\nghi", "\n", 4)))
end)

test("chunk delim landing on the default buffer boundary", function ()
  local line = repeated(63, "x")
  local content = repeated(400, line .. "\n")
  local expect = {}
  for i = 1, 400 do
    expect[i] = line
  end
  assert(teq(expect, segments(content, "\n", 8192)))
end)

test("chunk delim run spanning a refill", function ()
  assert(teq({ "ab", "cd" }, segments("ab\n\ncd", "\n", 3)))
  assert(teq({ "ab", "cd" }, segments("ab\n\ncd", "\n", 4)))
  assert(teq({ "ab", "cd" }, segments("ab\n\n\n\ncd\n", "\n", 3)))
  assert(teq({}, segments("\n\n\n", "\n", 2)))
end)

test("chunk leading and repeated delims", function ()
  assert(teq({ "a", "b" }, segments("\na\n\nb\n", "\n", 16)))
  assert(teq({ "a", "b" }, segments("\na\n\nb", "\n", 2)))
end)

test("chunk trailing delim variants", function ()
  assert(teq({ "abc", "de" }, segments("abc\nde\n", "\n", 16)))
  assert(teq({ "abc", "de" }, segments("abc\nde", "\n", 16)))
  assert(teq({ "abcd" }, segments("abcd", "\n", 4)))
  assert(teq({ "abcd" }, segments("abcd\n", "\n", 5)))
end)

test("chunk mixed delim sets", function ()
  assert(teq({ "this", "is", "a", "test" },
    segments("this|is|a|test\n", "|\n", 6)))
  assert(teq({ "a", "b", "c" }, segments("a|\n|b\nc", "|\n", 3)))
end)

test("chunk segmentation is independent of buffer size", function ()
  local contents = {
    "",
    "\n\n\n",
    "alpha\nbeta\ngamma\n",
    "alpha\nbeta\ngamma",
    "\nalpha\n\n\nbeta\n",
    "a\nbb\nccc\ndddd\n",
    "one|two\nthree|\nfour",
    repeated(9, "record|") .. "last",
  }
  for i = 1, #contents do
    local content = contents[i]
    local expect = smatches(content, "[^|\n]+")
    local longest = 0
    for j = 1, #expect do
      if #expect[j] > longest then
        longest = #expect[j]
      end
    end
    for size = longest + 1, #content + 3 do
      assert(teq(expect, segments(content, "|\n", size)),
        "size " .. size .. " content " .. i)
    end
  end
end)

test("chunk blocks without delims", function ()
  assert(teq({ "abcd", "efgh" }, blocks("abcdefgh", 4)))
  assert(teq({ "abcd", "efg" }, blocks("abcdefg", 4)))
  assert(teq({ "abcd" }, blocks("abcd", 4)))
  assert(teq({}, blocks("", 4)))
end)

test("chunk empty file", function ()
  assert(teq({}, segments("", "\n", 8)))
  assert(teq({}, blocks("", 8)))
end)

test("chunk doesnt fit after a refill", function ()
  local fp = write_chunk_tmp("ab\nabcdefgh")
  assert(teq({ false, "chunk doesn't fit", 3, 7 },
    { pcall(icollect, fs.chunks(fp, "\n", 4)) }))
  clean_tmp("test/tmp")
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
  assert(teq(asort(icollect(fs.dirs("test/res", true)), scmp), {
    "test/res/fs",
    "test/res/fs/a",
    "test/res/fs/b",
  }))
  assert(teq(asort(icollect(fs.dirs("test/res", false)), scmp), {
    "test/res/fs",
  }))
end)

if fs.symlink then

  local function make_link_tmp (dir)
    clean_tmp(dir)
    fs.mkdirp(dir .. "/sub")
    fs.symlink("a.txt", dir .. "/aaa_link")
    fs.symlink(".", dir .. "/aaa_loop")
    fs.writefile(dir .. "/a.txt", "a")
    fs.writefile(dir .. "/b.txt", "b")
    fs.writefile(dir .. "/c.txt", "c")
    fs.writefile(dir .. "/sub/d.txt", "d")
  end

  test("walk yields non-directory entries without truncating", function ()
    local dir = "test/tmp/links"
    make_link_tmp(dir)
    assert(teq(asort(imap(apack, fs.walk(dir)), function (a, b)
      return a[1] < b[1]
    end), {
      { dir .. "/a.txt", "file" },
      { dir .. "/aaa_link", "link" },
      { dir .. "/aaa_loop", "link" },
      { dir .. "/b.txt", "file" },
      { dir .. "/c.txt", "file" },
      { dir .. "/sub", "directory" },
      { dir .. "/sub/d.txt", "file" },
    }))
    clean_tmp("test/tmp")
  end)

  test("files skips symlinks and yields every regular file", function ()
    local dir = "test/tmp/links"
    make_link_tmp(dir)
    assert(teq(asort(icollect(fs.files(dir, true))), {
      dir .. "/a.txt",
      dir .. "/b.txt",
      dir .. "/c.txt",
      dir .. "/sub/d.txt",
    }))
    assert(teq(asort(icollect(fs.files(dir, false))), {
      dir .. "/a.txt",
      dir .. "/b.txt",
      dir .. "/c.txt",
    }))
    assert(teq(asort(icollect(fs.dirs(dir, true))), {
      dir .. "/sub",
    }))
    clean_tmp("test/tmp")
  end)

end

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

