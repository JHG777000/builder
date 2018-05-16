# builder

builder is a work in progress build automation tool with a simple and easy to use syntax.

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

 	  message("hello, world.\n").

 	  copy("MyApp","build","project").
	
 	  launch(MyApp).

 	  launch(MyApp2).

	end build.



## Platform Support

Currently builder works under macOS, is untested on linux, limited testing under Windows. Not all features work under Windows as of now.

## Toolchain Support

builder plans to support gcc, clang, and msvc(only on Windows). Gcc and clang work under macOS, an install of gcc on Windows works with most cases. msvc support and full Windows support, work in progress.