## Example 1

An example of a basic project with builder.

To build this project use this command:

	builder
	
Also, one can specify command line options for a given buildfile, if a buildfile is set up for command line options. This buildfile allows one to specify its toolchain, either gcc or clang, this buildfile defaults to gcc.

To build this project, and specify the toolchain 'gcc' use this command:

	builder -i __t_gcc
	
To build this project, and specify the toolchain 'clang' use this command:

	builder -i __t_clang