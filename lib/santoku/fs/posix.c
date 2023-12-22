#include "lua.h"
#include "lauxlib.h"

#include <dirent.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <fcntl.h>
#include <utime.h>

int tk_fs_posix_err (lua_State *L, int err)
{
  lua_pushboolean(L, 0);
  lua_pushstring(L, strerror(errno));
  lua_pushinteger(L, err);
  return 3;
}

int tk_fs_posix_dir_closure (lua_State *L)
{
  luaL_checktype(L, lua_upvalueindex(1), LUA_TLIGHTUSERDATA);
  DIR *d = (DIR *) lua_touserdata(L, lua_upvalueindex(1));
  struct dirent *entry = readdir(d);
  if (entry != NULL) {
    lua_pushboolean(L, 1);
    lua_pushstring(L, entry->d_name);
    switch (entry->d_type) {
      case DT_BLK:
        lua_pushstring(L, "block");
        break;
      case DT_CHR:
        lua_pushstring(L, "character");
        break;
      case DT_DIR:
        lua_pushstring(L, "directory");
        break;
      case DT_FIFO:
        lua_pushstring(L, "fifo");
        break;
      case DT_LNK:
        lua_pushstring(L, "link");
        break;
      case DT_REG:
        lua_pushstring(L, "file");
        break;
      case DT_SOCK:
        lua_pushstring(L, "socket");
        break;
      default:
        lua_pushstring(L, "unknown");
        break;
    }
    return 3;
  } else {
    int rc = closedir(d);
    if (rc == -1)
      return tk_fs_posix_err(L, errno);
    lua_pushboolean(L, 1);
    return 1;
  }
}

int tk_fs_posix_dir (lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
	DIR *d = opendir(path);
	if (d == NULL)
    return tk_fs_posix_err(L, errno);
  lua_pushboolean(L, 1);
  lua_pushlightuserdata(L, d);
  lua_pushcclosure(L, tk_fs_posix_dir_closure, 1);
  return 2;
}

int tk_fs_posix_rmdir (lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
  int rc = rmdir(path);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  lua_pushboolean(L, 1);
  return 1;
}

int tk_fs_posix_mkdir (lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
  int rc = mkdir(path, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  lua_pushboolean(L, 1);
  return 1;
}

int tk_fs_posix_cwd (lua_State *L)
{
  char cwd[PATH_MAX];
  if (getcwd(cwd, PATH_MAX) == NULL)
    return tk_fs_posix_err(L, errno);
  lua_pushboolean(L, 1);
  lua_pushstring(L, cwd);
  return 2;
}

int tk_fs_posix_touch (lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
  int fd = open(path, O_WRONLY|O_NONBLOCK|O_CREAT|O_NOCTTY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
  if (fd == -1)
    return tk_fs_posix_err(L, errno);
  if (close(fd) == -1)
    return tk_fs_posix_err(L, errno);
  int rc = utimes(path, NULL);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  lua_pushboolean(L, 1);
  return 1;
}

int tk_fs_posix_cd (lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
  if (chdir(path) == -1)
    return tk_fs_posix_err(L, errno);
  lua_pushboolean(L, 1);
  return 1;
}

int tk_fs_posix_mode (lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
  struct stat statbuf;
  int rc = stat(path, &statbuf);
  if (rc == -1)
    return tk_fs_posix_err(L, errno);
  lua_pushboolean(L, 1);
  int m = statbuf.st_mode;
  if (S_ISBLK(m)) {
    lua_pushstring(L, "block");
  } else if (S_ISCHR(m)) {
    lua_pushstring(L, "character");
  } else if (S_ISDIR(m)) {
    lua_pushstring(L, "directory");
  } else if (S_ISFIFO(m)) {
    lua_pushstring(L, "fifo");
  } else if (S_ISLNK(m)) {
    lua_pushstring(L, "link");
  } else if (S_ISREG(m)) {
    lua_pushstring(L, "file");
  } else if (S_ISSOCK(m)) {
    lua_pushstring(L, "socket");
  } else {
    lua_pushstring(L, "unknown");
  }
  return 2;
}

luaL_Reg tk_fs_posix_fns[] =
{
  { "rmdir", tk_fs_posix_rmdir },
  { "dir", tk_fs_posix_dir },
  { "mode", tk_fs_posix_mode },
  { "mkdir", tk_fs_posix_mkdir },
  { "cwd", tk_fs_posix_cwd },
  { "cd", tk_fs_posix_cd },
  { "touch", tk_fs_posix_touch },
  { NULL, NULL }
};

int luaopen_santoku_fs_posix (lua_State *L)
{
  lua_newtable(L);
  luaL_register(L, NULL, tk_fs_posix_fns);
  return 1;
}
