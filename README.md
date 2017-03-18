# Linux port of RISC OS

This is the binary distribution of the Linux port of RISC OS.

This is experimantial software, there is a good chance it won't work!

It is currenly being discussed on the [RISC OS Open website](https://www.riscosopen.org/forum/forums/3/topics/9068).

## Linux RISC OS command line options

| Option       | Action                                          |
| ---          | ---                                             |
| --help       | Display help message                            |
| --nvram FILE | Filename for nvram                              |
| --notimers   | Disable HAL timers                              |
| --noaborts   | Disable aborts - RISC OS will die with SIGSEGV  |
| --nofork     | Dont't fork - for debuging                      |
| --noseccomp  | Disable seccomp support                         |
