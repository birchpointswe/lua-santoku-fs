local err = require("santoku.error")
local wrapnil = err.wrapnil
local checknil = err.checknil
local checkok = err.checkok
local error = err.error
local pcall = err.pcall
local assert = err.assert

local lua = require("santoku.lua")
local loadstring = lua.loadstring

local inherit = require("santoku.inherit")
local pushindex = inherit.pushindex

local validate = require("santoku.validate")
local hasargs = validate.hasargs
local hascall = validate.hascall
local hasindex = validate.hasindex
local ge = validate.ge
local isstring = validate.isstring
local isboolean = validate.isboolean
local isnumber = validate.isnumber
local isfile = validate.isfile

local str = require("santoku.string")
local ssplit = str.split
local ssub = str.sub
local sfind = str.find

local fun = require("santoku.functional")
local noop = fun.noop

local tbl = require("santoku.table")
local tassign = tbl.assign

local iter = require("santoku.iter")
local idrop = iter.drop
local itail = iter.tail
local ifilter = iter.filter
local ifirst = iter.first
local ilast = iter.last

local arr = require("santoku.array")
local acat = arr.concat

local varg = require("santoku.varg")
local vreduce = varg.reduce
local vtup = varg.tup

local _open = wrapnil(io.open)
local stdout = io.stdout
local stderr = io.stderr
local stdin = io.stdin
local tmpname = wrapnil(os.tmpname)

local posix = require("santoku.fs.posix")
local chdir = posix.cd
local cwd = posix.cwd
local ENOENT = posix.ENOENT
local EEXIST = posix.EEXIST
local mkdir = posix.mkdir
local rmdir = posix.rmdir
local mode = posix.mode
local diropen = posix.diropen
local dirent = posix.dirent
local next_chunk = posix.next_chunk

local function open (fpfh, flag)
  if isfile(fpfh) then
    return fpfh, true
  else
    assert(isstring(fpfh))
    if flag ~= nil then
      assert(isstring(flag))
    end
    return _open(fpfh, flag), false
  end
end

local function read (fh, ...)
  assert(isfile(fh))
  return checknil(fh:read(...))
end

local function write (fh, ...)
  assert(isfile(fh))
  return checkok(fh:write(...))
end

local function close (fh, ...)
  assert(isfile(fh))
  return checkok(fh:close(...))
end

local function flush (fh, ...)
  assert(isfile(fh))
  return checkok(fh:flush(...))
end

local function seek (fh, ...)
  assert(isfile(fh))
  return checknil(fh:seek(...))
end

local function setvbuf (fh, ...)
  assert(isfile(fh))
  return checkok(fh:setvbuf(...))
end

local function with (fp, flag, fn, ...)
  local fh, was_open = open(fp, flag)
  return vtup(function (ok, ...)
    if not was_open then
      close(fh)
    end
    if not ok then
      error(...)
    else
      return ...
    end
  end, pcall(fn, fh, ...))
end

local function chunks (fp, delims, size, omit)
  local fh, was_open = open(fp, "r")
  local chunk, ss, se, ds, de
  return function ()
    return vtup(function (ok, ...)
      if not ok then
        if not was_open then
          close(fh)
        end
        error(...)
      else
        chunk, ss, se, ds, de = ...
        if chunk then
          return chunk, ss, omit and se or de
        elseif not was_open then
          close(fh)
        end
      end
    end, pcall(next_chunk, fh, delims, size, chunk, ss, se, ds, de))
  end
end

local function lines (fp, size)
  return chunks(fp, "\r\n", size, true)
end

local function join (...)
  assert(hasargs(...))
  local hastrailing = false
  return acat(vreduce(function (a, n)
    assert(isstring(n))
    if not a[1] then
      a[1] = n
    elseif hastrailing or sfind(n, "^/") then
      a[#a + 1] = n
    else
      a[#a + 1] = "/"
      a[#a + 1] = n
    end
    hastrailing = sfind(n, "/$")
    return a
  end, {}, ...))
end

local function dirname (fp)
  assert(isstring(fp))
  local s, e = sfind(fp, "^.*/")
  if not s then
    return "."
  else
    return ssub(fp, s, e - 1)
  end
end

local function basename (fp)
  assert(isstring(fp))
  local s, e = sfind(fp, "^.*/")
  if not s then
    return fp
  elseif e == #fp then
    return nil
  else
    return ssub(fp, e + 1)
  end
end

local function extension (fp, all)
  assert(isstring(fp))
  local s, e = sfind(fp, "^.*/")
  e = s and e + 1 or 1
  s, e = sfind(fp, all and "%..*$" or "%.[^.]*$", e)
  return s and ssub(fp, s, e) or nil
end

local function extensions (fp)
  assert(isstring(fp))
  return extension(fp, true)
end

local function stripextension (fp, all)
  assert(isstring(fp))
  local s = sfind(fp, all and "%..*$" or "%.[^.]*$")
  if s then
    return ssub(fp, 1, s - 1)
  else
    return fp
  end
end

local function stripextensions (fp)
  assert(isstring(fp))
  return stripextension(fp, true)
end

local function _string_is_zero_len (_, s, e)
  return e >= s
end

local function splitparts (fp, delim)
  assert(isstring(fp))
  return ifilter(_string_is_zero_len, ssplit(fp, "/+", delim))
end

local function splitexts (fp, keep_dots)
  assert(isstring(fp))
  local s = sfind(fp, "%..*$")
  if not s then
    return noop
  else
    return itail(ssplit(fp, "%.", keep_dots and "right" or false, s))
  end
end

local function stripparts (fp, n, keep_sep)
  assert(isstring(fp))
  assert(isnumber(n))
  assert(ge(n, 0))
  if n == 0 then
    return fp
  end
  return vtup(function (...)
    local _, s0, e0 = ifirst(...)
    local _, s1, e1 = ilast(...)
    if s0 and not s1 then
      return ssub(fp, s0, e0)
    elseif s0 and e1 then
      return ssub(fp, s0, e1)
    end
  end, idrop(n, ifilter(function (str, s, e)
    if e < s then
      return false
    else
      local s0, e0 = sfind(str, "/+", s)
      return not s0 or not (s0 == s and e0 == e)
    end
  end, ssplit(fp, "/+", keep_sep and "right" or "left"))))
end

local function dir (fp)
  assert(isstring(fp))
  local d = diropen(fp)
  return function ()
    local f, m = dirent(d)
    if f then
      return f, m
    end
  end
end






local function walk (fp, prune, leaves)

  assert(isstring(fp))
  prune = prune or noop
  assert(hascall(prune))
  leaves = leaves or false
  assert(isboolean(leaves))

  local names = { fp }
  local stack = { dir(fp) }
  local modes = {}

  local function helper ()
    local ents = stack[#stack]
    if not ents then
      return
    elseif type(ents) == "string" then
      local mode = modes[#stack]
      modes[#stack] = nil
      stack[#stack] = nil
      return ents, mode
    end
    local name, mode = ents()
    if not name then
      stack[#stack] = nil
      return helper()
    elseif name == ".." or name == "." then
      return helper()
    else
      name = join(names[#stack], name)
      if mode == "file" then
        return name, mode
      elseif mode == "directory" then
        local shouldprune = prune(name, mode)
        if not shouldprune then
          if not leaves then
            stack[#stack + 1] = dir(name)
            names[#stack] = name
            return name, mode
          else
            stack[#stack + 1] = name
            modes[#stack] = mode
            stack[#stack + 1] = dir(name)
            return helper()
          end
        elseif shouldprune == "keep" then
          return name, mode
        else
          return helper()
        end
      end
    end
  end

  return helper

end

local function files (fp, recurse)
  return ifilter(function (_, m)
    return m == "file"
  end, walk(fp, not recurse and function (_, m)
    return m == "directory"
  end))
end

local function dirs (fp, recurse, leaves)
  return ifilter(function (_, m)
    return m == "directory"
  end, walk(fp, not recurse and function (_, m)
    return m == "directory" and "keep"
  end, leaves))
end

local function isdir (fp)
  return vtup(function (ok, mode, code, ...)
    if (not ok and code == ENOENT) or (ok and mode ~= "directory") then
      return false
    elseif not ok then
      return error(mode, code, ...)
    else
      return true
    end
  end, pcall(mode, fp))
end

local function isfile (fp)
  return vtup(function (ok, mode, code, ...)
    if (not ok and code == ENOENT) or (ok and mode ~= "file") then
      return false
    elseif not ok then
      return error(mode, code, ...)
    else
      return true
    end
  end, pcall(mode, fp))
end

local function exists (fp)
  return vtup(function (ok, mode, code, ...)
    if not ok and code == ENOENT then
      return false
    elseif ok then
      return true, mode
    else
      return error(mode, code, ...)
    end
  end, pcall(mode, fp))
end

local function mkdirp (fp)
  assert(isstring(fp))
  local s0 = nil
  for str, s, e in splitparts(fp, "right") do
    s0 = s0 or s
    local dir = ssub(str, s0, e)
    local ok, err, cd = pcall(mkdir, dir)
    if not ok and cd ~= EEXIST then
      error(err, cd, dir)
    end
  end
end

local function rm (fp, allow_noexist)
  assert(isstring(fp))
  allow_noexist = allow_noexist or false
  assert(isboolean(allow_noexist))
  return vtup(function (ok, err, cd, ...)
    if not ok and (not allow_noexist and cd == ENOENT) then
      return error(err, cd, ...)
    end
  end, os.remove(fp))
end

local function mv (old, new)
  assert(isstring(old))
  assert(isstring(new))
  return vtup(function (ok, ...)
    if not ok then
      return error(...)
    end
  end)
end

local function rmdirs (dir)
  assert(isstring(dir))
  for _, d in dirs(dir, true, true) do
    rmdir(d)
  end
end


local function writefile (fp, str, flag)
  return with(fp, flag or "w", function (fh)
    write(fh, str)
    flush(fh)
  end)
end

local function readfile (fp, flag)
  return with(fp, flag or "r", function (fh)
    return read(fh, "*all")
  end)
end

local function loadfile (fp, env)
  return loadstring(readfile(fp), env)
end

local function runfile (fp, env, nog)
  env = env or {}
  assert(hascall(env) or hasindex(env))
  local lenv = nog and env or pushindex(env, _G)
  return loadfile(fp, lenv)()
end

local function pushd (fp, fn, ...)
  assert(isstring(fp))
  assert(hascall(fn))
  local cwd = cwd()
  chdir(fp)
  return vtup(function (ok, ...)
    chdir(cwd)
    if not ok then
      error(...)
    else
      return ...
    end
  end, pcall(fn, ...))
end

return tassign({
  with = with,
  open = open,
  close = close,
  read = read,
  write = write,
  seek = seek,
  setvbuf = setvbuf,
  flush = flush,
  stdout = stdout,
  stderr = stderr,
  stdin = stdin,
  exists = exists,
  mkdirp = mkdirp,
  rm = rm,
  mv = mv,
  rmdirs = rmdirs,
  writefile = writefile,
  readfile = readfile,
  loadfile = loadfile,
  runfile = runfile,
  tmpname = tmpname,
  isdir = isdir,
  isfile = isfile,
  join = join,
  dirname = dirname,
  basename = basename,
  extension = extension,
  extensions = extensions,
  stripextension = stripextension,
  stripextensions = stripextensions,
  splitparts = splitparts,
  splitexts = splitexts,
  stripparts = stripparts,
  chunks = chunks,
  lines = lines,
  dir = dir,
  walk = walk,
  files = files,
  dirs = dirs,
  pushd = pushd,
}, posix, false)
