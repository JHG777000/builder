# Manual


## About

builder is a build automation tool with a simple and easy to use syntax. This manual describes builder's buildfile syntax and command line options, as well as its project directory structure.
 
## Ninja

builder makes use of the ninja build system. Ninja need not be installed, builder will download ninja automatically. It may be helpful to better understand builder, to understand the build system its built on: [ninja][1].

[1]:https://ninja-build.org

## Directories

### Output

The output directory is where the project directory exists, defaults to the current working directory. The output directory can be changed with the -o flag.

### Project

This directory exists within the output directory. The project directory contains all build cache, object files, and all built targets, as well as all build.ninja files and ninja itself. A local subproject's project directory exists within the superproject's project directory, while a global subproject's project directory exists within the superproject's output directory. 

### Resources

The resources directory is the source directory. The resources directory is by default the current working directory. A subproject's resources directory is the directory of the subprojects's buildfile. A downloaded project's resources directory is or within the directory with the name of the project plus "_src", that in turn exists within the project directory.


### Download project version files

The download\_project\_ver\_files directory exists with the path: "project/.build/project/download\_project\_ver\_files". If the current project name is "foo", then the download\_project\_ver\_files directory's path is: "foo/.build/foo/download\_project\_ver\_files". The download\_project\_ver_files directory stores downloaded project version files. These files are for updating downloaded projects via the -d flag. Each file is the name of its project and contains the current version of that project as a string.

### Build

The build directory exists with the path: "project/.build/project/os". If the current project name is "foo", and the OS is Windows, then the build directory's path is: "foo/.build/foo/windows". The build directory contains the target output directories. 

### Target Outputs

The target output directories exist within the build directory. Not to be confused with the output directory, each target output directory contains the built target and its intermediate files. The name of a target output directory is 'name of target' plus "_output".

### Ninja

The ninja directory exists with the path: "project/.build/ninja/os". If the current project name is "foo", and the OS is Windows, then the ninja directory's path is: "foo/.build/ninja/windows". The ninja directory contains the build.ninja file and associated files as well as ninja itself. Subprojects do not contain ninja. NOTE: The build.ninja file will be copied into the current working directory during the build process, and then deleted afterward.

## Options

### -f, --filename=name
	
	
	 Filename of the buildfile. Default filename is 'buildfile'.
	 
### -b, --build_select=build
	
	
	 Select the build to run in the buildfile.
	 
### -i, --input\_build_options=input
	
	
	 Give a string containing command-line options(in options string format) to be used as input for the running build. Format example: '-t gcc' is to be input as '__t_gcc'. One underscore is space, two is '-', three is '_', four is reset.
	 
### -u, --url\_to_buildfile=buildfile
	
	
	 Give a URL to a buildfile for a project to be downloaded and built.
	 
The url\_to_src value must be set in the buildfile. Will download a project only once, however, will update a project by deleting and redownloading the current downloaded source, if the downloaded buildfile's project version is less than the online buildfile's project version.
	 
### -d, --download_project
	
	
	 Download the project from the given buildfile, build with the given buildfile.
	 
   The url\_to\_src value must be set in the buildfile. Also, after the url\_to_src value is set, the resources directory becomes the  downloaded source directory. Will download a project only once, however, will update a project by deleting and redownloading the current downloaded source, if the version stored in the downloaded project version file is less than the given buildfile's project version.

### -a, --allow\_extern_exec
	
	
	 Allow execution of external(outside working directory) programs or scripts via the run function.
	 
If the -a flag is not given, the run function will append "./" to the start of its input before executing.

### -e, --external\_move\_or_copy
	
	
	 Allow external move or copy, where the destination can be outside of the output directory, via the external function.
	 
If the -e flag is not given, the external function will fail.

### -l, --local\_subprojects_force
	
	
	Force all subprojects to be local.
	 
This will affect all subprojects of the current project, and their subprojects. A local subproject's project directory exists within the superproject's project directory.

### -g, --global\_subprojects_force
	
	
	Force all subprojects of this project to be global.
	 
This only affects the subprojects of the current project, not the subprojects of subprojects. A global subproject's project directory exists within the superproject's output directory.

### -o, --output_directory=output
	
	
	Set the output directory(the directory where the project is built), defaults to the current working directory.
	 
The output directory is where the project directory exists. If you wish to set the output directory to be outside of the current working directory, use "../".

### -p, --project\_force_update
	
	
	Force the current project to update.
	 
The url\_to_src value must be set in the buildfile. Will delete and redownload the current downloaded source.

### -h, --help
	
	
	Prints help.
	 

Prints the list of builder's command line options and brief descriptions.

## Syntax

builder's syntax is designed to be simple, straight forward and powerful.

### Ruby

builder's syntax takes some influence from the Ruby programming language, as it is itself written in Ruby, but more so all buildfile code is "compiled" into Ruby and executed in a Ruby environment. As such it may be a good idea to familiarize with Ruby, in particular builder's error checking is minimal, and a builder syntax error in many cases becomes a Ruby one, and as such Ruby will generate a Ruby error message.

### Syntax basics

    project := "My Project".

	project_version := "1.0".

	buildfile_version := "1.0".

	 build mybuild.

	  files MyAppSourceFiles("foo.c").

 	  sources MyAppSource(MyAppSourceFiles).

 	  compiler MyCompilerFlags("-Wall").

 	  toolchain MyToolChain("gcc",MyCompilerFlags).

 	  output MyApp("application",MyAppSource,MyToolChain).

	end build.
	
In the above example, an application is built that has the name "MyApp", with the gcc toolchain with the complier flag "-Wall", from the source "foo.c", for the build "mybuild" in the project "My Project", with project version being 1.0 and, the buildfile version is also 1.0.

builder's syntax is based on the concept of "Objects", and "Builds".

### File information values

Before builds can be defined, the file information values must be set. The values can be set in any order. They must exist outside of a build. 

	project := "My Project".
	
The project value sets the name of the project. The name of the project directory is the name of the project. If there is a space in the project name, a "\_" will substitute that space, such that "My Project", will become "My_Project".

	project_version := "1.0".
	
The project\_version value sets the version of the project. The version must be a string. Adding a ".", will increase the value of the version, such that "1.0.0" is greater than "1.0".

	buildfile_version := "1.0".
	
The buildfile_version value sets the buildfile version. The version must be a string. builder will use this value to determine whether it can run a buildfile, whether it be the buildfile requires new features, and builder needs to be updated or whether builder no longer supports older features and syntax used in the buildfile.

### url\_to_src

	url_to_src := "https://...(valid url).../foo_archive/foo_src.zip".

The url\_to\_src value is a url to a zip file that contains the source of a project. This value must exist outside of a build. After this value is set, the resources directory becomes the downloaded source directory. All builds are executed after this change takes place, but include statements are not. Only include statements after the url\_to_src value will have the resources directory be the downloaded source directory.

### Builds

Builds encapsulate a build process that builds a given set of targets from specified sources. Most of the buildfile is encapsulate within a build, and most of builder's statements and keywords must be placed inside of a build. However, includes, file information values, url\_to_src value, and the default statement, must exist outside of a build.

Builds start with the 'build' keyword:

	build mybuild.
	
The above example starts a build with the name of "mybuild". Also, note the '.' at the end, all lines in builder end with ".".

Builds end with the 'end' keyword, followed by 'build':

	end build.
	
All builds must end, before the end of the buildfile, and the start of another build.

You can have multiple builds in a buildfile, only one can be ran at a time. You can have builds with the same name, later builds with the same name will be appended on to earlier builds with that name. To select the active build one can use the -b flag or the default statement. If there are multiple builds, no default statement, and no -b flag set, then builder will prompt the user with a list of all builds in the buildfile, and ask the name of the desired build to be typed in.

The default statement is shown below:

	default mybuild.
	
Default statements are the 'default' keyword, followed by the name of the build to be default. The -b flag overrides the default statement. The default statement, must exist outside of a build.

### Objects

Objects contain all information needed for the build process. The type of an object determines what information it holds.

The basic syntax of an object is:

	object_type name(arguments...).
	
The arguments are stored in the newly created object with the specified name.

Objects can be referenced by their name just like any other variable. An object's arguments can be variables, strings, or other objects.

Some objects enforce stricter type checking than others, as some objects enforce a specific order for arguments, based on the type and value of the argument.

Some objects will cause side effects, or actions not given explicitly but implicitly. The biggest example of this is the output object, which upon creation will cause the build process to commence.

### files

The files object takes any number of file paths or names. When used as an input to a sources object, all files must have an extension.

The following are source file extensions supported by builder and the files object:

	c, cc, cpp, c++, cxx, C, m, mm
	
Files with these extensions are viewed as source files, and turned into object files.

NOTE: Objective-C support requires clang.

The following are object file extensions supported by builder and the files object:

	o, a, obj, lib, dylib, so
	
Files with these extensions are viewed as object files, and are statically linked. In the case of dylib and so, for dynamic libraries to be loaded automatically by an executable at run time, the executable needs symbol information from the dynamic libraries. Dll does not appear on this list because the needed symbol information is stored in an associated .lib file.

Builder will change extensions based on OS and toolchain, such that "mylib.a" on Mac with clang will become "mylib.lib" on Windows with msvc. This allows a cross-platform way of specifying files, assuming "mylib.a", and "mylib.lib" are in the same directory.

The directory and directories extension allows multiple files to be specified at once by their directory. These extensions can only be applied to directories, unlike with other extensions, there is no expectation that the directory in question actually has an extension, in fact the directory and directories extension are actually removed from the file path.

 	directory, directories
 	
The directory extension will iterate every item in the given directory, sorting files based on the their extensions. The directories extension is the same as the directory extension, but recursive.

Files object example:

	files MyAppSourceFiles("foo.c").
	
Creates a files object named "MyAppSourceFiles", with one file path to a source file, "foo.c".


### sources

The sources object takes any number of files, libraries, frameworks, or output objects.


Sources object example:

	sources MyAppSource(MyAppSourceFiles).
	
Creates a sources object named "MyAppSource", containing one files object, "MyAppSourceFiles".

Some compilers are sensitive to the order of source files, mostly with static libraries, and object files.

### libraries

The libraries object takes any number of library names. On gcc and clang an '-l' is appended to the start of its name. On msvc, ".lib" is appended to the end of its name. Make sure a given library is properly setup and/or installed.

### library_names

The library_names object takes any number of library names. On gcc and clang an '-' is appended to the start of its name. On msvc, ".lib" is appended to the end of its name. Make sure a given library is properly setup and/or installed.

### frameworks

The frameworks object takes any number of framework names, ".framework" is appended to the end of its name, via the "-framework" flag. This is a Mac only feature.  Make sure a given framework is properly setup and/or installed.

### compiler, linker, archiver, dlinker, and path

The compiler, linker, archiver, and dlinker objects allow flags to the compiler, linker, and archiver, to be set. In addition the path object allows the path to the compiler, linker, and archiver, to be set, overriding the specified toolchain.

#### compiler

The compiler object allows flags to the compiler to be set. The path object can be used to override the program path of the compiler from the specified toolchain.

#### linker

The linker object allows flags to the linker to be set. The path object can be used to override the program path of the linker from the specified toolchain.

#### archiver

The archiver object allows flags to the archiver to be overridden. The path object can be used to override the program path of the archiver from the specified toolchain. Default archiver flags for gcc and clang are "rcs", the default archiver flags for msvc are "/nologo /ltcg".

#### dlinker

The dlinker object does not refer to the dynamic linker but the program that generates a dynamic library, usually the complier with specific settings. The dlinker object allows flags to the dynamic library generating program to be set. The path object can be used to override the program path of the dynamic library generating program from the specified toolchain.

#### path

The path object allows the path to the compiler, linker, archiver, and dynamic library generating program to be set, overriding the specified toolchain. Allowing the compiler, linker, archiver, and dynamic library generating program to be directly and manually specified.

### toolchain

The toolchain object must be provided a string that is the name of a supported toolchain, it can have any number of compiler, linker, archiver, and dlinker objects.

List of supported toolchains:

	Windows: gcc, g++, clang, clang++, and msvc
	
    Linux: gcc, g++, clang, and clang++
    
    Mac: gcc, g++, clang, and clang++
    

Toolchain object example:

	toolchain MyToolChain("gcc",MyCompilerFlags).
	
Creates a toolchain object named "MyToolChain", that uses the toolchain "gcc", and passes flags from compiler object "MyCompilerFlags" to the compiler.

### output

The output object represents a build target. The first argument must be a string of either, "application" or "library" or "dynamic_library", specifying the build target type. The output object must be given a toolchain object. The output object takes any number of sources objects. Creating an output object will cause the build target to be built. An output object can be used later as input into a sources object. 

Output object example:

	output MyApp("application",MyAppSource,MyToolChain).
	
Creates a output object named "MyApp", as well as builds the target "MyApp", an application from source provided in "MyAppSource", and with the toolchain, "MyToolChain". The built target in this case an application with the name "MyApp".

#### build target types

##### application

An executable, on Windows will have the extension ".exe", on Mac and Linux, no extension.

##### library

A static library, with msvc will have the extension ".lib", on clang and gcc, ".a".

##### dynamic_library

A dynamic library, on Windows will have the extension ".dll", on Mac ".dylib", and on Linux, ".so".

### subproject

The subproject object represents another project the current project is dependent on, a subproject.

The first argument must be either the string "local" or "global".

If the first argument is the string "local", then the subproject will be a local subproject. A local subproject's project directory exists within the superproject's project directory.

If the first argument is the string "global", then the subproject will be a global subproject. A global subproject's project directory exists within the superproject's output directory.

The second argument must be either a url object or a files object, a url object must contain a string of a valid url to a buildfile. If a url object is given then the buildfile must have the url\_to_src value set. The files object if given, must contain a string of a valid path to a buildfile.

The third argument must be either a string of command line options or nil.

The following is the list of command line options that can be used on a subproject:
	
	 -b,  --build_select=build, Select the build to run in the buildfile.
	
     -i, --input_build_options=input", "Give a string containing command-line options(in options string format) to be used as input for the running build. Format example: '-t gcc' is to be input as '__t_gcc'. One underscore is space, two is '-', three is '_', four is reset.
    
     -d --download_project, Download the project from the given buildfile, build with the given buildfile.
    
	 -a, --allow_extern_exec, Allow execution of external(outside working directory) programs or scripts via the run function.

	 -e, --external_move_or_copy, Allow external move or copy, where the destination can be outside of the output directory, via the external function.

	 -l, --local_subprojects_force, Force all subprojects to be local.

	 -g, --global_subprojects_force, Force all subprojects of this project to be global.

	 -p, --project_force_update, Force the current project to update.

	 -h, --help, Prints help.
	 
#### url

A url object must contain a string of a valid url to a buildfile, the given buildfile must have the url\_to_src value set.

Subproject and url object example:

    url URLForFoo("https://...(valid url).../foo/buildfile").

    subproject foo_subproject("local",URLForFoo,nil).
	
Creates a subproject object named "foo\_subproject", from the url to buildfile: "https://...(valid url).../foo/buildfile", and with no command line options.

#### grab statement

The grab statement allows the retrieval of output objects from a subproject object. Grabbed  output objects can be used as any other output object.

The grab statement is shown below:

	grab foo from foo_subproject.
	
Grab statements are the 'grab' keyword, followed by the name of the output object to be retrieved. The output object's name is the name it is given when created, in the subproject. Followed by the 'from' keyword, followed by the name of the subproject object. Subproject object names do not need to reflect the names of projects they represent.

#### return_output statement

By default grab can only retrieve output objects from an immediate subproject, not a    subproject of the subproject. If it is necessary for a superproject to have access to a  subproject's subproject output objects, then the subproject should use the return_output statement. Returned output objects are available to a subproject's immediate superproject, just as its own output objects are.

The return_output statement is shown below:

	return_output foo.
	
This will allow the superproject to access the foo output object via the grab statement, as if it had been created in an immediate subproject.

In addition the return_output statement can return a subproject object.

 	return_output foo_subproject.
 	
This will provide access to the subproject object created in a subproject to its immediate superproject. Returned subproject objects can be retrieved the same way as output objects via 'grab'. The grab statement can then retrieve output objects from the returned subproject object.

  	grab foo_subproject from bar_subproject.
  	
    grab foo from foo_subproject.
    
### Variables

Like variables in any other programming language, variables are identifiers that store data or values. Variables themselves do not have type, but their values do, as well as their assignments. Variables that start with an uppercase letter, with the exception of objects, are constants.

#### Predefined

The following are predefined variables in builder:

	is_win, true on Windows
	
	is_mac, true on Mac
	
	is_linux, true on Linux
	
#### Assignments

Assignments in builder look like variable declarations in other strongly typed languages, but variables in builder do not need to be declared before use and are the type of the value they hold. However, assignments in builder do have types.

Example of assignments in builder:

	string hello := "test.c".

 	float num := (5.6).

 	bool stuff := true.
 	
    float hello := (5.6). //valid, these are assignments not declarations
 	
The syntax of an assignment is as follows:

	type variable := value.
	
Assignment types:

	 string, value assigned must be a string
	
	 float, must be a numerical value, allows parentheses to encapsulate a value, parentheses are needed for decimal points
	
	 bool, must be either 'true' or 'false'
	 
     var, can be another variable, a string, a bool or a non-decimal point number
     

#### Eval

Eval statements allow operations to be performed and evaluated on variables.

The syntax of an eval statement is as follows:

	eval variable_a := variable_b operation value.


Example of eval statements in builder:

    float num := (5.6). //while variables do not need to be declared, operations can not be performed on empty variables, and values whose type is incompatible with the given operation

	eval hello := hello + ".g".

 	eval num := num + 1.
     
Supported operations:

	+, -, *, /, %

### Control flow

builder supports if statements, while statements, and unless statements.

Example of an if statement:

	if ( (7.6) == value ).

  	 eval value := value + 1.

    end if.
    
Example of a while statement:

	while ( i < 100 ).

  	 eval i := i + 1.

    end while.
    
Example of an unless statement:

	unless ( (7.6) == value ).

  	 eval value := value + 1.

    end unless.
    
### Options statement

The options statement allows a build to receive command line options via the -i flag.

Example of the options statement:

 	options.

  	 on test_enable("-t", "--test", "Enable test.").

  	 on toolchain_select("-s", "--select_toolchain=tool", "Select toolchain, clang or gcc.").

 	end options.
 	
The get statement must be used to retrieve the result of an on statement.

Example of the get statement:

	get test_enable.

 	get toolchain_select.
 	
test_enable will hold a value of a bool, will be true if the -t flag is set.

toolchain_select will hold a value of a string, will be whatever the value of the -s flag is.

The -h flag is automatically defined as:

	'-h', '--help', 'Prints help.'
	
The -h flag will print all command line options for the options statement.

Only one options statement can exist in a build.

### Make filepath statement

The make filepath statement allows for the retrieval of a filepath relative to builder's directory structure.

The syntax of a make filepath statement is as follows:

	make filepath variable from directory_name to local_file_path.
	
Variable is assigned to the value of the filepath to the directory\_name, plus the local\_file_path.

Example of the make filepath statement:

	make filepath include_path from "resources" to "include".
	
Example of the make filepath statement, with 'from' allowing the retrieval of a filepath relative to a subroject:
	
	make filepath subroject_include_path from "resources" to "include" from foo_subroject.


### get\_file_exist statement

Sets a variable to true or false, depending on whether the given file exists.

	true, file exists.
	
	false, file does not exist.
	
Example of the get\_file_exist statement:

	get_file_exist file_bool_var for file "filename".

### Include statement

The include statement will include another buildfiles.

Example of the include statement:

	include "src/buildfile" from "resources".
	
Will include the buildfile with the path "src/buildfile" in the directory "resources". 

Included buildfiles will have builds with the same name as the current build appended on to it at the end.

Included buildfiles must have the same file information values as the main buildfile.
	
### Functions

All functions in builder are predefined. builder does not support user defined functions.

This is a list of all functions in builder:

	message(string).
	
The message function prints string to standard output. It will add a newline.

	setup(program,setup_name,dest_dir).
	
The setup function, sets up a program that is dependent on dynamic
libraries, such that the exe file and all  dynamic
libraries are put into the setup(setup\_name)
directory, to be stored in dest\_dir(a directory name).

On Mac install\_name_tool -change is used to have the exe load the
 dynamic
libraries in the directory.

On Linux chrpath -r is used to have the exe load the dynamic
libraries in the
directory.

Not intended for final release of a program, for release one should distribute, package and/or install dynamic libraries as is best on the program's supported platforms.

	move(src_file,src_dir,dest_dir).
	
Move a file(src\_file) from src\_dir(a directory name), to dest_dir(a directory name).

	copy(src_file,src_dir,dest_dir).
	
Copy a file(src\_file) from src\_dir(a directory name), to dest_dir(a directory name).

	move_output(src,dest_dir).
	
Move a file(an output object), to dest_dir(a directory name).

	copy_output(src,dest_dir).
	
Copy a file(an output object), to dest_dir(a directory name).

	external(op,src,dest)
	
Move or copy a file from src(a file path), to dest(a directory path).

External function needs op to be either 'move' or 'copy'.

If the -e flag is not given, the external function will fail.

	clean(dir).
	
Clean or remove a directory given by its directory name in dir, dir cannot be "resources", "working", or "output".

	clean_output(output).
	
Removes the target output directory associated with the given output object.

	remove(file,dirname)
	
Removes a file with the file path from 'file', that exists within the directory given by its directory name(dirname).

	change_working_directory_to(directory).
	
Change the current working directory to directory(a directory name).

	display_working_directory().
	
Prints the path of the current working directory to standard output.

	launch(output).
	
Launch the program represented by the given output object.

Launch cannot pass command line arguments to the program to be launched.

	run(path).
	
Run the program at the given file path(a string).

Run can pass command line arguments to the program to be run.

If the -a flag is not given, the run function will append "./" to the start of its input before executing.