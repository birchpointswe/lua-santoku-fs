# Now

- Catch errors and close handles for file and directory operations
- allow file handles or file paths for most functions that operate on files
- mkdir, touch, writefile set mode
- fchunks allow pattern for delim

# Later

- Potential optimization for fs.chunk with delims: instead of rewinding the
  file, copy the chunk tail to the new chunk
