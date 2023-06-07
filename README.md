# Linux Syscall Table Generator

This tool generates the Linux x86 and x64 syscall tables in Markdown format.

See the generated tables here:

- [Linux x64 syscall table](https://yuankun.me/syscall64/)
- [Linux x86 syscall table](https://yuankun.me/syscall32/)

To use it, you need to have a local copy of the Linux source tree. Then run:

```sh
./gen.sh <path-to-linux-source-tree> 32     # x86 syscall table
./gen.sh <path-to-linux-source-tree> 64     # x64 syscall table
```
