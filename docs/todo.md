# Now

- Allow iterator as input for writefile

# Later

- Custom modes for touch, mkdir, writefile
- Add chmod, chown

- Allow Lua pattern for chunk delim

- Potential optimization for fs.chunk with delims
    - Instead of rewinding the file, copy the chunk tail to the new chunk
