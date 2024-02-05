# Now

- Catch errors and close handles for file and directory operations
- Allow file handles or file paths for most functions that operate on files
- Allow iterator as input for writefile

# Later

- Custom modes for touch, mkdir, writefile
- Add chmod, chown

- Allow Lua pattern for delim

- Potential optimization for fs.chunk with delims
    - Instead of rewinding the file, copy the chunk tail to the new chunk
