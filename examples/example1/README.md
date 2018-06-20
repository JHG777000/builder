## Example 1

An example of a basic project with builder.

To build this project use this command:

	builder
	
Also, one can specify command line options for a given buildfile, if a buildfile is set up for command line options. This buildfile allows one to specify its toolchain, either gcc or clang, this buildfile defaults to gcc.

To build this project, and specify the toolchain 'gcc' use this command:

	builder -i __t_gcc
	
To build this project, and specify the toolchain 'clang' use this command:

	builder -i __t_clang
	

The -i option specifies input build options, a string containing command-line options(in options string format) to be used as input for the running build. Format example: '-t gcc' is to be input as '\_\_t\_gcc'. One underscore is space, two is '-', three is '_', four is reset."