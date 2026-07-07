local test = require("santoku.test")

local err = require("santoku.error")
local assert = err.assert

local validate = require("santoku.validate")
local eq = validate.isequal

local fs = require("santoku.fs")

test("writefile/readfile round-trip", function ()
  local fp = "test/res/io_rt.txt"
  fs.rm(fp, true)
  fs.writefile(fp, "hello")
  assert(eq("hello", fs.readfile(fp)))
  fs.writefile(fp, " more", "a")
  assert(eq("hello more", fs.readfile(fp)))
  fs.rm(fp)
end)

test("with closes the handle and returns fn results", function ()
  local fp = "test/res/io_with.txt"
  fs.rm(fp, true)
  fs.writefile(fp, "abc")
  local out = fs.with(fp, "r", function (fh)
    return fs.read(fh, "*all")
  end)
  assert(eq("abc", out))
  fs.rm(fp)
end)

test("loadfile/runfile", function ()
  local fp = "test/res/io_script.lua"
  fs.rm(fp, true)
  fs.writefile(fp, "return 1 + 2")
  assert(eq(3, fs.loadfile(fp)()))
  assert(eq(3, fs.runfile(fp)))
  fs.rm(fp)
end)

test("touch creates an empty file", function ()
  local fp = "test/res/io_touch.txt"
  fs.rm(fp, true)
  fs.touch(fp)
  assert(fs.isfile(fp))
  assert(eq("", fs.readfile(fp)))
  fs.rm(fp)
end)

test("mv renames", function ()
  local a = "test/res/io_mv_a.txt"
  local b = "test/res/io_mv_b.txt"
  fs.rm(a, true)
  fs.rm(b, true)
  fs.writefile(a, "x")
  fs.mv(a, b)
  assert(not fs.exists(a))
  assert(eq("x", fs.readfile(b)))
  fs.rm(b)
end)

test("pushd runs in dir then restores cwd", function ()
  local before = fs.cwd()
  local seen = fs.pushd("test/res", function ()
    return fs.cwd()
  end)
  assert(seen ~= before)
  assert(eq(before, fs.cwd()))
end)
