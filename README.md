# builder

builder is a build automation tool with a simple and easy to use syntax.

## About

builder provides an easy to use syntax to describe the build process, as can be seen below in the example buildfile. You can also look at [RKLib][1]'s buildfile [here][2], which makes use of more advanced features than the example buildfile. You should also check out the other example buildfiles in the examples folder.

 [1]:https://github.com/JHG777000/RKLib
 [2]:https://github.com/JHG777000/RKLib/blob/master/buildfile

 Example of a buildfile for a simple project: 
	
	project := "My Project".

	project_version := "1.0".

	buildfile_version := "1.0".

	 build mybuild.

 	  options.

  	   on toolchain_select("-t", "--toolchain=tool", "Select toolchain, clang or gcc.").

 	  end options.

 	  get toolchain_select.
 
 	  if ( toolchain_select != "clang" && toolchain_select != "gcc" ).

  	   var toolchain_select := "clang".

 	  end if.

	  files MyAppSourceFiles("foo.c").

 	  sources MyAppSource(MyAppSourceFiles).

 	  compiler MyCompilerFlags("-Wall").

 	  toolchain MyToolChain(toolchain_select,MyCompilerFlags).

 	  output MyApp("application",MyAppSource,MyToolChain).

 	  output MyApp2("application",MyAppSource,MyToolChain).

 	  message("hello, world.").
	
 	  launch(MyApp).

 	  launch(MyApp2).

	end build.



## Installing 

Download or clone builder, place builder in your home directory. The folder containing builder should itself be named 'builder', such that 'builder.rb' is at '~/builder/builder/builder.rb'. Add the 'run' directory to your system path. Make sure you have that latest version of [ruby][3]. On Mac, its recommended that you use [brew][4] to get the latest version of ruby.

 [3]:https://www.ruby-lang.org/en/
 [4]:https://brew.sh
 
The toolchains builder supports are separate programs that need to be installed as well.
 
## Platform Support

builder plans to fully support Windows, macOS, and linux. Currently builder is known to work(more or less) under Windows, and macOS. builder is untested on linux.

## Toolchain Support

builder supports gcc, clang, and msvc(only on Windows). While builder provides these toolchains, projects that use builder may not support all toolchains, or only one, or work better on some than others, consult the project 's documentation and/or build instructions. Make sure a toolchain is properly installed before using it.

## Ninja

builder makes use of the ninja build system: https://ninja-build.org. 

Ninja need not be installed, builder will download ninja automatically.
