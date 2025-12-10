local err = require("santoku.error")
local wrapnil = err.wrapnil
local checknil = err.checknil
local checkok = err.checkok
local error = err.error
local pcall = err.pcall


local lua = require("santoku.lua")
local loadstring = lua.loadstring

local inherit = require("santoku.inherit")
local pushindex = inherit.pushindex

local validate = require("santoku.validate")
local isfile = validate.isfile








local str = require("santoku.string")
local ssplit = str.splits
local ssub = str.sub
local sfind = str.find

local fun = require("santoku.functional")
local noop = fun.noop

local tbl = require("santoku.table")
local tmerge = tbl.merge

local arr = require("santoku.array")
local acat = arr.concat

local _open = wrapnil(io.open)
local stdout = io.stdout
local stderr = io.stderr
local stdin = io.stdin
local tmpname = wrapnil(os.tmpname)
local rename = wrapnil(os.rename)

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




    return _open(fpfh, flag), false
  end
end

local function read (fh, ...)

  return checknil(fh:read(...))
end

local function write (fh, ...)

  return checkok(fh:write(...))
end

local function close (fh, ...)

  return checkok(fh:close(...))
end

local function flush (fh, ...)

  return checkok(fh:flush(...))
end

local function seek (fh, ...)

  return checknil(fh:seek(...))
end

local function setvbuf (fh, ...)

  return checkok(fh:setvbuf(...))
end

local function with (fp, flag, fn, ...)
  local fh, was_open = open(fp, flag)
  return (function (ok, ...)
    if not was_open then
      close(fh)
    end
    if not ok then
      error(...)
    else
      return ...
    end
  end)(pcall(fn, fh, ...))
end

local function chunks (fp, delims, size, omit)
  local fh, was_open = open(fp, "r")
  local chunk, ss, se, ds, de
  return function ()
    return (function (ok, ...)
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
    end)(pcall(next_chunk, fh, delims, size, chunk, ss, se, ds, de))
  end
end

local function join (...)
  local hastrailing = false
  local a = {}
  for i = 1, select("#", ...) do
    local n = select(i, ...)
    if not a[1] then
      a[1] = n
    elseif hastrailing or sfind(n, "^/") then
      a[#a + 1] = n
    else
      a[#a + 1] = "/"
      a[#a + 1] = n
    end
    hastrailing = sfind(n, "/$")
  end
  return acat(a)
end

local function dirname (fp)

  local s, e = sfind(fp, "^.*/")
  if not s then
    return "."
  else
    return ssub(fp, s, e - 1)
  end
end

local function basename (fp)

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

  local s, e = sfind(fp, "^.*/")
  e = s and e + 1 or 1
  s, e = sfind(fp, all and "%..*$" or "%.[^.]*$", e)
  return s and ssub(fp, s, e) or nil
end

local function extensions (fp)

  return extension(fp, true)
end

local function stripextension (fp, all)

  local s = sfind(fp, all and "%..*$" or "%.[^.]*$")
  if s then
    return ssub(fp, 1, s - 1)
  else
    return fp
  end
end

local function stripextensions (fp)

  return stripextension(fp, true)
end

local function splitparts (fp, delim)
  local parts = ssplit(fp, "/+", delim)
  local i = 0
  return function ()
    while true do
      i = i + 1
      if i > #parts then return end
      local str = parts[i]
      if str ~= "" then
        return str
      end
    end
  end
end

local function splitexts (fp, keep_dots)
  local s = sfind(fp, "%..*$")
  if not s then
    return noop
  end
  local parts = ssplit(fp, "%.", keep_dots and "right" or false, s)
  local i = 1
  return function ()
    i = i + 1
    if i > #parts then return nil end
    return parts[i]
  end
end

local function stripparts (fp, n, keep_sep)
  if n == 0 then
    return fp
  end
  local parts = ssplit(fp, "/+", keep_sep and "right" or "left")
  local filtered = {}
  for i = 1, #parts do
    local str = parts[i]
    if str ~= "" then
      local s0 = sfind(str, "^/+$")
      if not s0 then
        filtered[#filtered + 1] = str
      elseif #filtered > n then
        filtered[#filtered] = filtered[#filtered] .. str
      end
    end
  end
  if n >= #filtered then
    return nil
  end
  local result = {}
  for i = n + 1, #filtered do
    result[#result + 1] = filtered[i]
  end
  return acat(result, "")
end

local function dir (fp)

  local d = diropen(fp)
  return function ()
    local f, m = dirent(d)
    if f then
      return f, m
    end
  end
end






local function walk (fp, prune, leaves)


  prune = prune or noop

  leaves = leaves or false


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
            names[#stack] = name
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
  local w = walk(fp, not recurse and function (_, m)
    return m == "directory"
  end)
  return function ()
    while true do
      local name, mode = w()
      if not name then return end
      if mode == "file" then
        return name, mode
      end
    end
  end
end

local function dirs (fp, recurse, leaves)
  local w = walk(fp, not recurse and function (_, m)
    return m == "directory" and "keep"
  end, leaves)
  return function ()
    while true do
      local name, mode = w()
      if not name then return end
      if mode == "directory" then
        return name, mode
      end
    end
  end
end

local function isdir (fp)
  return (function (ok, m, code, ...)
    if (not ok and code == ENOENT) or (ok and m ~= "directory") then
      return false
    elseif not ok then
      return error(m, code, ...)
    else
      return true
    end
  end)(pcall(mode, fp))
end

local function isfile (fp)
  return (function (ok, m, code, ...)
    if (not ok and code == ENOENT) or (ok and m ~= "file") then
      return false
    elseif not ok then
      return error(m, code, ...)
    else
      return true
    end
  end)(pcall(mode, fp))
end

local function exists (fp)
  return (function (ok, m, code, ...)
    if not ok and code == ENOENT then
      return false
    elseif ok then
      return true, m
    else
      return error(m, code, ...)
    end
  end)(pcall(mode, fp))
end

local function mkdirp (fp)

  local accum = ""
  for part in splitparts(fp, "right") do
    accum = accum .. part
    local ok, err, cd = pcall(mkdir, accum)
    if not ok and cd ~= EEXIST then
      error(err, cd, accum)
    end
  end
end

local function rm (fp, allow_noexist)
  allow_noexist = allow_noexist or false
  return (function (ok, e, cd, ...)
    if not ok and (not allow_noexist and cd == ENOENT) then
      return error(e, cd, ...)
    end
  end)(os.remove(fp))
end

local function rmdirs (dir)

  for d in dirs(dir, true, true) do
    rmdir(d)
  end
  rmdir(dir)
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

  local lenv = nog and env or pushindex(env, _G)
  return loadfile(fp, lenv)()
end

local function pushd (fp, fn, ...)
  local cwd0 = cwd()
  chdir(fp)
  return (function (ok, ...)
    chdir(cwd0)
    if not ok then
      error(...)
    else
      return ...
    end
  end)(pcall(fn, ...))
end

return tmerge({
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
  mv = rename,
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
  dir = dir,
  walk = walk,
  files = files,
  dirs = dirs,
  pushd = pushd,
}, posix, io)
