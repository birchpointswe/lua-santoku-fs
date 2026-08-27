local test = require("santoku.test")

local err = require("santoku.error")
local assert = err.assert

local validate = require("santoku.validate")
local eq = validate.isequal

local tbl = require("santoku.table")
local teq = tbl.equals

local arr = require("santoku.array")
local icollect = arr.icollect

local fs = require("santoku.fs")

test("write and read a whole file", function ()
  fs.mkdirp("test/res")
  fs.writefile("test/res/anchor.txt", "hello\n")
  assert(eq("hello\n", fs.readfile("test/res/anchor.txt")))
  fs.rm("test/res/anchor.txt", true)
end)

test("read a file line by line", function ()
  fs.writefile("test/res/anchor_lines.txt", "one\ntwo\nthree\n")
  assert(teq({ "one", "two", "three" }, icollect(fs.lines("test/res/anchor_lines.txt"))))
  fs.rm("test/res/anchor_lines.txt", true)
end)

test("take paths apart and put them back together", function ()
  assert(eq("a/b", fs.join("a/", "b")))
  assert(eq("/opt/bin", fs.dirname("/opt/bin/sort")))
  assert(eq("sort", fs.basename("/opt/bin/sort")))
  assert(eq("archive", fs.stripextension("archive.tar")))
end)

test("run inside a directory, then end up back where you started", function ()
  local before = fs.cwd()
  fs.mkdirp("test/res/anchor_dir")
  fs.pushd("test/res/anchor_dir", function ()
    assert(eq("anchor_dir", fs.basename(fs.cwd())))
  end)
  assert(eq(before, fs.cwd()))
  fs.rmdirs("test/res/anchor_dir")
end)
