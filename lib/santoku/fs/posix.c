#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include <dirent.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <fcntl.h>
#include <utime.h>

#define TK_FS_DIR_MT "santoku_fs_dir"

void tk_fs_callmod (lua_State *L, int nargs, int nret, const char *smod, const char *sfn)
{
  lua_getglobal(L, "require");
  lua_pushstring(L, smod);
  lua_call(L, 1, 1);
  lua_pushstring(L, sfn);
  lua_gettable(L, -2);
  lua_remove(L, -2);
  lua_insert(L, - nargs - 1);
  lua_call(L, nargs, nret);
}

int tk_fs_posix_err (lua_State *L, int err)
{
  lua_pushstring(L, strerror(errno));
  lua_pushinteger(L, err);
  tk_fs_callmod(L, 2, 0, "santoku.error", "error");
  return 0;
}

int tk_fs_posix_dirclose (lua_State *L)
{
  DIR **dirp = (DIR **) luaL_checkudata(L, 1, TK_FS_DIR_MT);
  if (*dirp == NULL)
    return 0;
  if (closedir(*dirp))
    return tk_fs_posix_err(L, errno);
  *dirp = NULL;
  return 0;
}

int tk_fs_posix_diropen (lua_State *L)
{
  lua_settop(L, 1);
	const char *path = luaL_checkstring(L, 1);
  DIR **dirp = lua_newuserdata(L, sizeof(DIR *));
  luaL_getmetatable(L, TK_FS_DIR_MT);
  lua_setmetatable(L, -2);
	*dirp = opendir(path);
	if (*dirp == NULL)
    return tk_fs_posix_err(L, errno);
  return 1;
}

const char *tk_fs_posix_typename (mode_t m)
{
  if (S_ISBLK(m)) {
    return "block";
  } else if (S_ISCHR(m)) {
    return "character";
  } else if (S_ISDIR(m)) {
    return "directory";
  } else if (S_ISFIFO(m)) {
    return "fifo";
  } else if (S_ISLNK(m)) {
    return "link";
  } else if (S_ISREG(m)) {
    return "file";
  } else if (S_ISSOCK(m)) {
    return "socket";
  } else {
    return NULL;
  }
}

int tk_fs_posix_dirent (lua_State *L)
{
  lua_settop(L, 1);
  DIR **dirp = (DIR **) luaL_checkudata(L, 1, TK_FS_DIR_MT);
  if (*dirp == NULL)
    return 0;
  errno = 0;
  struct dirent *ent = readdir(*dirp);
  if (ent == NULL && errno != 0)
    return tk_fs_posix_err(L, errno);
  if (ent == NULL && errno == 0)
    return tk_fs_posix_dirclose(L);
  const char *type;
  switch (ent->d_type) {
    case DT_BLK:
      type = "block";
      break;
    case DT_CHR:
      type = "character";
      break;
    case DT_DIR:
      type = "directory";
      break;
    case DT_FIFO:
      type = "fifo";
      break;
    case DT_LNK:
      type = "link";
      break;
    case DT_REG:
      type = "file";
      break;
    case DT_SOCK:
      type = "socket";
      break;
    default: {
      struct stat statbuf;
      if (fstatat(dirfd(*dirp), ent->d_name, &statbuf, AT_SYMLINK_NOFOLLOW) == -1)
        return tk_fs_posix_err(L, errno);
      type = tk_fs_posix_typename(statbuf.st_mode);
      if (type == NULL) {
        lua_pushstring(L, "unknown directory entry type");
        lua_pushinteger(L, statbuf.st_mode);
        tk_fs_callmod(L, 2, 0, "santoku.error", "error");
        return 0;
      }
      break;
    }
  }
  lua_pushstring(L, ent->d_name);
  lua_pushstring(L, type);
  return 2;
}

int tk_fs_posix_absolute (lua_State *L)
{
  lua_settop(L, 1);
  size_t fplen;
  const char *fp = luaL_checklstring(L, 1, &fplen);

  if (fplen == 0)
  {
    lua_pushnil(L);
    return 1;
  }

  char *abs = realpath(fp, NULL);

  if (abs == NULL && errno != ENOENT)
    return tk_fs_posix_err(L, errno);

  char *fpnew = NULL;

  if (fp[0] == '/' ||
      (strncmp(fp, "./", 2) == 0) ||
      (strncmp(fp, "../", 3) == 0)) {
    fpnew = strdup(fp);
  } else {
    fpnew = (char*) malloc(fplen + 3);
    strcpy(fpnew, "./");
    strcat(fpnew, fp);
  }

  for (int i = strlen(fpnew) - 1; i >= 0 && abs == NULL; i --) {
    if (fpnew[i] == '/') {
      fpnew[i] = '\0';
      abs = realpath(fpnew, NULL);
      if (abs != NULL) {
        char *fpmerge = (char*) malloc(strlen(abs) + strlen(fpnew + i + 1) + 2);
        strcpy(fpmerge, abs);
        strcat(fpmerge, "/");
        strcat(fpmerge, fpnew + i + 1);
        free(abs);
        abs = fpmerge;
      } else {
        fpnew[i] = '/';
      }
    }
  }

  if (abs != NULL)
    lua_pushstring(L, abs);

  free(fpnew);
  free(abs);

  return 1;
}

int tk_fs_posix_next_chunk (lua_State *L)
{
  lua_settop(L, 8);

  FILE **fhp = (FILE **) luaL_checkudata(L, 1, LUA_FILEHANDLE);
  if (fhp == NULL || *fhp == NULL)
    return 0;
  FILE *fh = *fhp;

  const char *delims = luaL_optstring(L, 2, NULL);

  lua_Integer chunk_max = luaL_optinteger(L, 3, BUFSIZ);
  if (chunk_max <= 0)
    return luaL_error(L, "next_chunk: chunk_max must be positive");

  size_t chunk_size;
  const char *chunk = luaL_optlstring(L, 4, NULL, &chunk_size);

  lua_Integer segment_start = luaL_optinteger(L, 5, 0);
  lua_Integer segment_end = luaL_optinteger(L, 6, 0);
  lua_Integer delim_start = luaL_optinteger(L, 7, 0);
  lua_Integer delim_end = luaL_optinteger(L, 8, 0);

  if (segment_start < 0 || segment_end < 0 || delim_start < 0 || delim_end < 0 ||
      (size_t) segment_start > chunk_size || (size_t) segment_end > chunk_size ||
      (size_t) delim_start > chunk_size || (size_t) delim_end > chunk_size)
    return luaL_error(L, "next_chunk: position out of range");

  while (1) {

    if (((delim_end != 0 && delim_end == chunk_size) ||
         (segment_end == chunk_size)) && feof(fh))
      return 0;

    if ((chunk == NULL || segment_end == chunk_size) && !feof(fh)) {

      luaL_Buffer buf;
      luaL_buffinit(L, &buf);

      size_t total_read = 0;

      while (1) {

        char *bufmem = luaL_prepbuffer(&buf);
        size_t chunk_left = chunk_max - total_read;
        size_t read_size = chunk_left > LUAL_BUFFERSIZE ? LUAL_BUFFERSIZE : chunk_left;
        size_t bytes_read = fread(bufmem, 1, read_size, fh);
        if (ferror(fh))
          return tk_fs_posix_err(L, errno);
        total_read += bytes_read;
        luaL_addsize(&buf, bytes_read);
        if (feof(fh) || total_read == (size_t) chunk_max)
          break;
      }

      if (!feof(fh)) {
        int next = fgetc(fh);
        if (next == EOF && ferror(fh))
          return tk_fs_posix_err(L, errno);
        if (next != EOF)
          ungetc(next, fh);
      }

      luaL_pushresult(&buf);
      chunk = luaL_checklstring(L, -1, &chunk_size);

      if (chunk_size == 0)
        return 0;

      segment_start = 1;

    } else {

      lua_pushvalue(L, 4);
      segment_start = delim_end + 1;

    }

    if (delims == NULL) {
      lua_pushinteger(L, segment_start);
      lua_pushinteger(L, chunk_size);
      return 3;
    }

    segment_start += strspn(chunk + segment_start - 1, delims);

    const char *delim_startp = strpbrk(chunk + segment_start - 1, delims);

    if (delim_startp == NULL) {

      if (feof(fh)) {
        if ((size_t) segment_start > chunk_size)
          return 0;
        lua_pushinteger(L, segment_start);
        lua_pushinteger(L, chunk_size);
        return 3;
      }

      if (segment_start == 1) {
        lua_pushstring(L, "chunk doesn't fit");
        long pos = ftell(fh);
        lua_pushinteger(L, pos - (long) chunk_size);
        lua_pushinteger(L, pos);
        tk_fs_callmod(L, 3, 0, "santoku.error", "error");
        return 0;
      }

      if (fseek(fh, (long) segment_start - 1 - (long) chunk_size, SEEK_CUR))
        return tk_fs_posix_err(L, errno);

      lua_pop(L, 1);
      chunk = NULL;
      continue;

    }

    delim_start = delim_startp - chunk + 1;
    segment_end = delim_start - 1;
    delim_end = delim_start + strspn(delim_startp, delims) - 1;

    lua_pushinteger(L, segment_start);
    lua_pushinteger(L, segment_end);
    lua_pushinteger(L, delim_start);
    lua_pushinteger(L, delim_end);
    return 5;
  }
}

int tk_fs_posix_tmpfile (lua_State *L)
{
  lua_settop(L, 1);
  FILE **filep = lua_newuserdata(L, sizeof(FILE *));
  *filep = tmpfile();
  if (*filep == NULL)
    return tk_fs_posix_err(L, errno);
  luaL_getmetatable(L, LUA_FILEHANDLE);
  lua_setmetatable(L, -2);
  return 0;
}

int tk_fs_posix_touch (lua_State *L)
{
  lua_settop(L, 1);
	const char *path = luaL_checkstring(L, 1);
  int fd = open(path,
      O_WRONLY | O_NONBLOCK | O_CREAT | O_NOCTTY,
      S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
  if (fd == -1)
    return tk_fs_posix_err(L, errno);
  if (close(fd) == -1)
    return tk_fs_posix_err(L, errno);
  int rc = utimes(path, NULL);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  return 0;
}

int tk_fs_posix_rmdir (lua_State *L)
{
  lua_settop(L, 1);
	const char *path = luaL_checkstring(L, 1);
  int rc = rmdir(path);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  return 0;
}

int tk_fs_posix_mkdir (lua_State *L)
{
  lua_settop(L, 1);
	const char *path = luaL_checkstring(L, 1);
  int rc = mkdir(path, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  return 0;
}

int tk_fs_posix_cwd (lua_State *L)
{
  lua_settop(L, 0);
  char cwd[PATH_MAX];
  if (getcwd(cwd, PATH_MAX) == NULL)
    return tk_fs_posix_err(L, errno);
  lua_pushstring(L, cwd);
  return 1;
}

int tk_fs_posix_cd (lua_State *L)
{
  lua_settop(L, 1);
	const char *path = luaL_checkstring(L, 1);
  if (chdir(path) == -1)
    return tk_fs_posix_err(L, errno);
  return 0;
}

int tk_fs_posix_mode (lua_State *L)
{
  lua_settop(L, 1);
	const char *path = luaL_checkstring(L, 1);
  struct stat statbuf;
  errno = 0;
  int rc = stat(path, &statbuf);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  const char *type = tk_fs_posix_typename(statbuf.st_mode);
  if (type == NULL) {
    lua_pushstring(L, "unknown file type");
    lua_pushinteger(L, statbuf.st_mode);
    tk_fs_callmod(L, 2, 0, "santoku.error", "error");
    return 0;
  }
  lua_pushstring(L, type);
  return 1;
}

#ifndef __EMSCRIPTEN__
int tk_fs_posix_hardlink (lua_State *L)
{
  lua_settop(L, 2);
  const char *oldpath = luaL_checkstring(L, 1);
  const char *newpath = luaL_checkstring(L, 2);
  if (link(oldpath, newpath) == -1)
    return tk_fs_posix_err(L, errno);
  return 0;
}

int tk_fs_posix_symlink (lua_State *L)
{
  lua_settop(L, 2);
  const char *target = luaL_checkstring(L, 1);
  const char *linkpath = luaL_checkstring(L, 2);
  if (symlink(target, linkpath) == -1)
    return tk_fs_posix_err(L, errno);
  return 0;
}
#endif

luaL_Reg tk_fs_posix_fns[] =
{
  { "next_chunk", tk_fs_posix_next_chunk },
  { "mode", tk_fs_posix_mode },
#ifndef __EMSCRIPTEN__
  { "hardlink", tk_fs_posix_hardlink },
  { "symlink", tk_fs_posix_symlink },
#endif
  { "touch", tk_fs_posix_touch },
  { "absolute", tk_fs_posix_absolute },
  { "tmpfile", tk_fs_posix_tmpfile },
  { "cd", tk_fs_posix_cd },
  { "cwd", tk_fs_posix_cwd },
  { "rmdir", tk_fs_posix_rmdir },
  { "mkdir", tk_fs_posix_mkdir },
  { "diropen", tk_fs_posix_diropen },
  { "dirclose", tk_fs_posix_dirclose },
  { "dirent", tk_fs_posix_dirent },
  { NULL, NULL }
};

int luaopen_santoku_fs_posix (lua_State *L)
{
  lua_newtable(L);
  luaL_register(L, NULL, tk_fs_posix_fns);
  lua_pushinteger(L, ENOENT); lua_setfield(L, -2, "ENOENT");
  lua_pushinteger(L, EEXIST); lua_setfield(L, -2, "EEXIST");
  luaL_newmetatable(L, TK_FS_DIR_MT);
  lua_pushcfunction(L, tk_fs_posix_dirclose);
  lua_setfield(L, -2, "__gc");
  lua_pop(L, 1);
  return 1;
}
