#Copyright (c) 2018-2025 Jacob Gordon. All rights reserved.

#Permission to redistribution and use this software in source and binary forms, with or without modification is hereby granted.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
#TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


require "open-uri"
require "optparse"
require "stringio"
require "fileutils"

options = {}

#https://stackoverflow.com/questions/9384756/after-installing-a-gem-within-a-script-how-do-i-load-the-gem?rq=1
begin
    gem "rubyzip"
    rescue LoadError
    system("gem install rubyzip")
    Gem.clear_paths
end

gem "rubyzip"
require "zip"

class BuildNinjaFile
    def dirs(dirname,r)
        Dir.each_child(dirname) { |entry|
            next if entry[0] == '.'
            unless Dir.exist?(dirname + "/" + entry)
                ext = entry.split(".")
                @objects.push  dirname + "/" + entry if ext[ext.length-1] == "o" || ext[ext.length-1] == "a" ||  ext[ext.length-1] == "obj"  || ext[ext.length-1] == "lib" || ext[ext.length-1] == "dylib" || ext[ext.length-1] == "so"
                @sources.push dirname + "/" + entry if ext[ext.length-1] == "c"  || ext[ext.length-1] == "cc" || ext[ext.length-1] == "cpp" || ext[ext.length-1] == "c++" || ext[ext.length-1] == "cxx" || ext[ext.length-1] == "C" || ext[ext.length-1] == "m" || ext[ext.length-1] == "mm" || ext[ext.length-1] == "s" || ext[ext.length-1] == "asm"
            end
            dirs(dirname + "/" + entry,r) if Dir.exist?(dirname + "/" + entry) && r
        }  
    end
   
   def process_files(files)
       files.array.each { |file|
           if file.class.name == "String"
            ext = file.split(".")
            @objects.push  @path_to_resources + file if ext[ext.length-1] == "o" || ext[ext.length-1] == "a" ||  ext[ext.length-1] == "obj"  || ext[ext.length-1] == "lib" || ext[ext.length-1] == "dylib" || ext[ext.length-1] == "so"
            @sources.push @path_to_resources + file if ext[ext.length-1] == "c"  || ext[ext.length-1] == "cc" || ext[ext.length-1] == "cpp" || ext[ext.length-1] == "c++" || ext[ext.length-1] == "cxx" || ext[ext.length-1] == "C" || ext[ext.length-1] == "m" || ext[ext.length-1] == "mm" || ext[ext.length-1] == "s" || ext[ext.length-1] == "asm"
            dirs @path_to_resources + file.chomp(".directory"), false if ext[ext.length-1] == "directory"
            dirs @path_to_resources + file.chomp(".directories"), true if ext[ext.length-1] == "directories"
           end
       }  
   end
   
   def process_sources(sources)
       sources.array.each { |source|
           
           if source.type == "files"
               process_files source  
           end
           if source.type == "libraries"
               source.array.each { |library|
                   @libraries.push library
               }  
           end
           
           if source.type == "library_names"
               source.array.each { |library_name|
                   @library_names.push library_name
               }
           end
           
           if source.type == "frameworks"
               source.array.each { |framework|  
                   @frameworks.push framework
               }
           end
           
           if source.type == "output"    
               @objects.push source.path_to_output
               source.output_libs.each { |lib|
                  @libs_from_outputs.push lib
               } 
           end
           #puts "objects: #{@objects}"
           #puts "sources: #{@sources}"
       }  
   end
   
   def process_toolchain(toolchain)
       toolchain.array.each { |t|
           if t.class.name == "String"
            @toolchain = t
            next
           end
           if t.type == "compiler"
            t.array.each { |flag|
               if flag.class.name == "String"
                @compiler_flags += flag
                @compiler_flags += " "
                next
               end
               if flag.type == "path"
                   flag.array.each { |p| 
                       @compiler_path = p
                   }  
               end
            }
           end
           
           if t.type == "linker"
               t.array.each { |flag|
                   if flag.class.name == "String"
                       @linker_flags += flag
                       @linker_flags += " "
                       next
                   end
                   if flag.type == "path"
                       flag.array.each { |p|
                           @linker_path = p
                       }
                   end
               }
           end
           if t.type == "archiver"
               t.array.each { |flag|
                   if flag.class.name == "String"
                       @archiver_flags += flag
                       @archiver_flags += " "
                       next
                   end
                   if flag.type == "path" 
                       flag.array.each { |p| 
                           @archiver_path = p
                       }
                   end
               }
           end
           if t.type == "dlinker"
               t.array.each { |flag| 
                   if flag.class.name == "String"
                       @dlinker_flags += flag
                       @dlinker_flags += " "
                       next
                   end
                   if flag.type == "path"
                       flag.array.each { |p| 
                           @dlinker_path = p
                       }
                   end
               }
           end
       }
       if @toolchain == nil
           puts "Toolchain not given."
           exit(1)
       end
       #puts "toolchain: #{@toolchain}"
       #puts "compiler_flags: #{@compiler_flags}" 
   end
   
   def initialize(builder,buildfile,project,superproject,path_to_project_files,ninja_path)
       #path_to_project_files --> input
       #superproject --> output
       @OS = GetOS.new
       @builder = builder
       @buildfile = buildfile
       @superproject = nil
       ext = superproject.split("/") unless superproject == nil
       @superproject = ext[ext.length-1] unless superproject == nil
       @path_to_resources = path_to_project_files
       @path_to_resources = "" if @path_to_resources == nil
       @path_to_project_directory = superproject + project + "/" unless superproject == nil
       @path_to_project_directory = project + "/" if superproject == nil
       @path_to_build_directory = @path_to_project_directory + ".build/#{project}/windows/" if @OS.is_windows?
       @path_to_build_directory = @path_to_project_directory + ".build/#{project}/mac/" if @OS.is_mac?
       @path_to_build_directory = @path_to_project_directory + ".build/#{project}/linux/" if @OS.is_linux?
       @path_to_ninja_directory = @path_to_project_directory + ".build/ninja/windows/" if @OS.is_windows?
       @path_to_ninja_directory = @path_to_project_directory + ".build/ninja/mac/" if @OS.is_mac?
       @path_to_ninja_directory = @path_to_project_directory + ".build/ninja/linux/" if @OS.is_linux?
       @path_to_ninja = ninja_path
       @ninja_string = ""
       @process_hash = Hash.new
       @process_hash["sources"] = method(:process_sources)
       @process_hash["toolchain"] = method(:process_toolchain)
   end
   
   def add_dollar_to_windows_filepath(path)
    i = 0     
    string = ""
    if @OS.is_windows?
    while i < path.length
       unless path[i] == ':'
        string += path[i]
       else
        string += '$'
        string += path[i]
       end
      i+=1
    end
    return string
    end
    path
   end
   
   def process_output(output,name)
       i = 0
       @compiler_path = nil
       @linker_path = nil
       @archiver_path = nil
       @compiler_flags = ""
       @linker_flags = ""
       @archiver_flags = ""
       @dlinker_flags = ""
       @toolchain = nil
       @objects = Array.new
       @sources = Array.new
       @libraries = Array.new
       @library_names = Array.new
       @frameworks = Array.new
       @libs_from_outputs = Array.new
       @compiler = Hash.new
       @compiler["clang"] = "clang"
       @compiler["clang++"] = "clang++"
       @compiler["gcc"] = "gcc"
       @compiler["g++"] = "g++"
       @compiler["msvc"] = "cl"
       @linker = Hash.new
       @linker["clang"] = "clang"
       @linker["clang++"] = "clang++"
       @linker["gcc"] = "gcc"
       @linker["g++"] = "g++"
       @linker["msvc"] = "cl"
       @archiver = Hash.new
       @archiver["clang"] = "ar"
       @archiver["clang++"] = "ar"
       @archiver["gcc"] = "ar"
       @archiver["g++"] = "ar"
       @archiver["msvc"] = "lib"
       @dlinker = Hash.new
       @dlinker["clang"] = "clang"
       @dlinker["clang++"] = "clang++"
       @dlinker["gcc"] = "gcc"
       @dlinker["g++"] = "g++"
       @dlinker["msvc"] = "cl"
       @objext = Hash.new
       @objext["clang"] = "o"
       @objext["clang++"] = "o"
       @objext["gcc"] = "o"
       @objext["g++"] = "o"
       @objext["msvc"] = "obj"
       @libext = Hash.new
       @libext["clang"] = "a"
       @libext["clang++"] = "a"
       @libext["gcc"] = "a"
       @libext["g++"] = "a"
       @libext["msvc"] = "lib"
       @dylibext = Hash.new
       @dylibext["clang"] = @dylibext["clang++"] = @dylibext["gcc"] = @dylibext["g++"] = "dylib" if @OS.is_mac?
       @dylibext["clang"] = @dylibext["clang++"] = @dylibext["gcc"] = @dylibext["g++"] = "so" if @OS.is_linux?
       @dylibext["clang"] = @dylibext["clang++"] = @dylibext["gcc"] = @dylibext["g++"] = "dll" if @OS.is_windows?
       @dylibext["msvc"] = "dll"
       @has_toolchain = Hash.new
       if @OS.is_windows?
           @has_toolchain["clang"] = true
           @has_toolchain["clang++"] = true
           @has_toolchain["gcc"] = true
           @has_toolchain["g++"] = true
           @has_toolchain["msvc"] = true
       end
       if @OS.is_mac?
           @has_toolchain["clang"] = true
           @has_toolchain["clang++"] = true
           @has_toolchain["gcc"] = true
           @has_toolchain["g++"] = true
           @has_toolchain["msvc"] = false
       end
       if @OS.is_linux?
           @has_toolchain["clang"] = true
           @has_toolchain["clang++"] = true
           @has_toolchain["gcc"] = true
           @has_toolchain["g++"] = true
           @has_toolchain["msvc"] = false
       end
       @output_type = Hash.new
       @output_type["application"] = "link_#{name}"
       @output_type["library"] = "archive_#{name}"
       @output_type["dynamic_library"] = "generate_#{name}"
       output.array.each { |o|
        if i == 0
         unless o.class.name == "String" && (o == "application" || o == "library" || o == "dynamic_library")
             puts 'Expected string of "application" or "library" or "dynamic_library" in output objects\'s first argument.'
             exit(1)
         end
        end
        @outtype = o if i == 0
        @process_hash[o.type].call o if i > 0
        i+=1  
       }
       if @toolchain == nil
           puts "Toolchain object is not given."
           exit(1)
       end
       unless @has_toolchain[@toolchain]
           puts "The given toolchain: #{@toolchain}, is not supported on this platform."
           exit(1)
       end
       @compiler[@toolchain] = @compiler_path unless @compiler_path == nil
       @linker[@toolchain] = @linker_path unless @linker_path == nil
       @archiver[@toolchain] = @archiver_path unless @archiver_path == nil
       @dlinker[@toolchain] = @dlinker_path unless @dlinker_path == nil
       deps_toolchain = @toolchain
       deps_toolchain = "gcc" if deps_toolchain == "clang" || deps_toolchain == "clang++" || deps_toolchain == "g++"
       @archiver_flags = "rcs" if @archiver_flags == "" && @toolchain != "msvc"
       @archiver_flags = "/nologo /ltcg" if @archiver_flags == "" && @toolchain == "msvc"
       @ninja_string += "builddir = #{@path_to_ninja_directory}\n"
       @ninja_string += "cflags = "
       @ninja_string += @compiler_flags
       @ninja_string += "\n"
       @ninja_string += "ldflags = "
       @ninja_string += @linker_flags
       @ninja_string += "\n"
       @ninja_string += "arflags = "
       @ninja_string += @archiver_flags
       @ninja_string += "\n"
       @ninja_string += "dlflags = "
       @ninja_string += @dlinker_flags
       @ninja_string += "\n"
       @ninja_string += "libs = "
       @frameworks.each { |framework|
           @ninja_string += "-framework "
           @ninja_string += framework
           @ninja_string += " "
           output.output_libs.push "-framework #{framework}"
       }
       @libraries.each { |library|
           @ninja_string += "-l" unless @toolchain == "msvc"
           @ninja_string += library
           @ninja_string += ".lib" if @toolchain == "msvc"
           @ninja_string += " "
           output.output_libs.push "-l#{library}" unless @toolchain == "msvc"
           output.output_libs.push "#{library}.lib" if @toolchain == "msvc"
       }
      @library_names.each { |library_name|
           @ninja_string += "-" unless @toolchain == "msvc"
           @ninja_string += library_name
           @ninja_string += ".lib" if @toolchain == "msvc"
           @ninja_string += " "
           output.output_libs.push "-#{library_name}" unless @toolchain == "msvc"
           output.output_libs.push "#{library_name}.lib" if @toolchain == "msvc"
       }
       @libs_from_outputs.each { |lib|
          @ninja_string += lib
          @ninja_string += " "
          output.output_libs.push lib
       }
       @ninja_string += "\n"
       @ninja_string += "msvc_deps_prefix = Note: including file:\n" if @toolchain == "msvc"
       @ninja_string += "rule cc_#{name}\n"
       @ninja_string += "  command = #{@compiler[@toolchain]} -MMD -MF $out.d $cflags -c $in -o $out\n" unless @toolchain == "msvc"
       @ninja_string += "  command = #{@compiler[@toolchain]} /showIncludes $cflags -c $in /Fo$out\n" if @toolchain == "msvc"
       @ninja_string += "  description = compiling $out...\n"
       @ninja_string += "  depfile = $out.d\n"
       @ninja_string += "  deps = #{deps_toolchain}\n"
       @ninja_string += "rule link_#{name}\n"
       @ninja_string += "  command = #{@linker[@toolchain]} $ldflags -o $out $in $libs\n" unless @toolchain == "msvc"
       @ninja_string += "  command = #{@linker[@toolchain]} $in $libs /nologo /link $ldflags /out:$out.exe\n" if @toolchain == "msvc"
       @ninja_string += "  description = linking: $out...\n"
       @ninja_string += "rule archive_#{name}\n"
       @ninja_string += "  command = #{@archiver[@toolchain]} $arflags $out $in\n" unless @toolchain == "msvc"
       @ninja_string += "  command = #{@archiver[@toolchain]} $arflags /out:$out $in\n" if @toolchain == "msvc"
       @ninja_string += "  description = archiving: $out...\n"
       @ninja_string += "rule generate_#{name}\n"
       @ninja_string += "  command = #{@dlinker[@toolchain]} -shared -fpic $dlflags $in -o $out\n" if @toolchain != "msvc" && !@OS.is_windows?
       @ninja_string += "  command = #{@dlinker[@toolchain]} -shared -fpic $dlflags $in -o $out -Wl,--out-implib=$olib\n" if @toolchain != "msvc" && @OS.is_windows?
       @ninja_string += "  command = #{@dlinker[@toolchain]} /LD $dlflags $in /Fe:$out\n" if @toolchain == "msvc"
       @ninja_string += "  description = generating: $out...\n"
       @sources.each { |source|
           ext = source.split("/")
           ext = ext[ext.length-1].split(".")
           if ext[ext.length-1] == "m" || ext[ext.length-1] == "mm" 
               if @toolchain != "clang" && @toolchain != "clang++"
                puts "Obj-C support requires clang."
                puts "Builder shutting down..."
                exit(1)
               end
           end
           @ninja_string += "build #{add_dollar_to_windows_filepath(@path_to_build_directory)}#{name}_output/#{ext[ext.length-2]}_object_#{name}.#{@objext[@toolchain]}: cc_#{name} #{add_dollar_to_windows_filepath(source)}"
           @ninja_string += " \n"
           @objects.push "#{add_dollar_to_windows_filepath(@path_to_build_directory)}#{name}_output/#{ext[ext.length-2]}_object_#{name}.#{@objext[@toolchain]}"
        }
        @ninja_string += "build #{add_dollar_to_windows_filepath(@path_to_build_directory)}#{name}_output/#{name}: " + @output_type[@outtype] + " " if @outtype == "application"
        @ninja_string += "build #{add_dollar_to_windows_filepath(@path_to_build_directory)}#{name}_output/#{name}.#{@libext[@toolchain]}: " + @output_type[@outtype] + " " if @outtype == "library"
        @ninja_string += "build #{add_dollar_to_windows_filepath(@path_to_build_directory)}#{name}_output/#{name}.#{@dylibext[@toolchain]}: " + @output_type[@outtype] + " " if @outtype == "dynamic_library"
        @objects.reverse!
        @objects.each { |object|
            ext = object.split(".")
            if ext[ext.length-1] == "o"
                object = object.chomp(".o")
                object += ".#{@objext[@toolchain]}"
            end
            if ext[ext.length-1] == "a"
               object = object.chomp(".a")
                object += ".#{@libext[@toolchain]}"
            end
            if ext[ext.length-1] == "obj"
                object = object.chomp(".obj")
                object += ".#{@objext[@toolchain]}"
            end
            if ext[ext.length-1] == "lib"
                
               object = object.chomp(".lib")
               
               object += ".#{@libext[@toolchain]}"
                
            end
            
            if ext[ext.length-1] == "dll"
                output.output_dylibs.push object
                object = object.chomp(".dll")
                object += ".#{@libext[@toolchain]}"
            end
            if ext[ext.length-1] == "so"
                object = object.chomp(".so")
                output.output_dylibs.push object + ".#{@dylibext[@toolchain]}"
                object += ".#{@dylibext[@toolchain]}" unless @OS.is_windows?
                object += ".#{@libext[@toolchain]}" if @OS.is_windows?
            end
            if ext[ext.length-1] == "dylib" 
                object = object.chomp(".dylib")
                output.output_dylibs.push object + ".#{@dylibext[@toolchain]}"
                object += ".#{@dylibext[@toolchain]}" unless @OS.is_windows?
                object += ".#{@libext[@toolchain]}" if @OS.is_windows?
            end
            @ninja_string += add_dollar_to_windows_filepath(object)
            @ninja_string += " "
        }
        @ninja_string += "\n"
        @ninja_string += " olib = #{add_dollar_to_windows_filepath(@path_to_build_directory)}#{name}_output/#{name}.#{@libext[@toolchain]} \n" if @outtype == "dynamic_library" && @toolchain != "msvc" && @OS.is_windows?
        output.path_to_output = "#{@path_to_build_directory}#{name}_output/#{name}" if @outtype == "application" && !@OS.is_windows?
        output.path_to_output = "#{@path_to_build_directory}#{name}_output/#{name}.exe" if @outtype == "application" && @OS.is_windows?
        output.path_to_output = "#{@path_to_build_directory}#{name}_output/#{name}.#{@libext[@toolchain]}" if @outtype == "library"
        output.path_to_output = "#{@path_to_build_directory}#{name}_output/#{name}.#{@dylibext[@toolchain]}" if @outtype == "dynamic_library"
        #puts @ninja_string
        puts "Building output: '#{name}'..."
        output
   end
   
   def write_file
       puts "Generating Ninja file..."
       unless File.exist?("#{@path_to_ninja}")
             FileUtils.remove_dir @path_to_ninja.chomp("ninja") unless @OS.is_windows?
             FileUtils.remove_dir @path_to_ninja.chomp("ninja.exe") if @OS.is_windows?
             puts "Ninja Missing..."
             puts "Relaunch builder and try again."
             exit(1)
       end
       file = File.new(@path_to_ninja_directory + "build.ninja","w")
       file.write(@ninja_string)
       file.close
       @ninja_string = ""
   end
   
   def run_ninja(name)
       puts "Running Ninja..."
       FileUtils.copy_file @path_to_ninja_directory + "build.ninja", Dir.pwd + "/build.ninja"
        unless system("./#{@path_to_ninja}")
            puts "NOTE FROM BUILDFILE: #{@builder.buildfile_error_string}\n" unless @builder.buildfile_error_string == nil
            puts "Ninja Failed."
            puts "Make sure the selected toolchain: #{@toolchain} is properly installed."
            puts "Check the documentation for the given buildfile: '#{@buildfile.filename}' and/or its project."
            FileUtils.remove_file Dir.pwd + "/build.ninja" if File.exist?(Dir.pwd + "/build.ninja")
            exit(1)
        end
        FileUtils.remove_file Dir.pwd + "/build.ninja" if File.exist?(Dir.pwd + "/build.ninja")
        puts "Ninja Succeeded."
        puts "Done building output: '#{name}'."
   end
end

class BuildFunctions
    def initialize(builder)
     @builder = builder
    end
    
    def message(msg)  
       puts msg
    end
    
    def set_buildfile_error_string(string)
       unless string.class.name == "String"
           puts "set_buildfile_error_string function needs a string."
           puts "Builder shutting down..."
           exit(1)
       end
       @builder.buildfile_error_string = string
    end
    
    def setup(program,setup_name,dest_dir)
        unless program.class.name == "Output"
            puts "Setup function needs an output object, for program."
            puts "Builder shutting down..."
            exit(1)
        end
        @builder.setup program, setup_name, dest_dir
    end
    
    def move(src_file,src_dir,dest_dir)
        @builder.move src_file,src_dir,dest_dir
    end
    
    def copy(src_file,src_dir,dest_dir)
        @builder.copy src_file,src_dir,dest_dir
    end
    
    def move_output(src,dest_dir)
        unless src.class.name == "Output"
            puts "Move_output function needs an output object, for src."
            puts "Builder shutting down..."
            exit(1)
        end
        dest_path = @builder.get_path_for_functions(dest_dir)
        FileUtils.move src.path_to_output, dest_path
    end
    
    def copy_output(src,dest_dir)
        unless src.class.name == "Output"
            puts "Copy_output function needs an output object, for src."
            puts "Builder shutting down..."
            exit(1)
        end
        dest_path = @builder.get_path_for_functions(dest_dir)
        FileUtils.copy src.path_to_output, dest_path
    end
    
    def external(op,src,dest)
        unless @builder.allowed_external_function
            puts "external function not allowed."
            puts "Builder shutting down..."
            exit(1)
        end
        unless op.class.name == "String"
            puts "external function needs a string object, for op."
            puts "Builder shutting down..."
            exit(1)
        end
        if op != "move" && op != "copy"
          puts "external function needs op to be either 'move' or 'copy'."
          puts "Builder shutting down..."
          exit(1)
        end
        src = src.path_to_output if src.class.name == "Output"
        FileUtils.move src, dest if op == "move"
        FileUtils.copy src, dest if op == "copy"
    end
    
    def clean(dir)
       @builder.clean dir
    end
    
    def clean_output(output)
        FileUtils.remove_dir @builder.get_path("build") + "#{output}_output" if File.exist?(@builder.get_path("build")  + "#{output}_output") 
    end
    
    def remove(file,dirname)
        return if file == nil || file == "" || file == " "
        FileUtils.remove_file @builder.get_path_for_functions(dirname) + file
    end
    
    def change_working_directory_to(directory)
        @builder.chdir directory
    end
    
    def display_working_directory()
        puts "Working directory is: '#{Dir.pwd}'."
    end
    
    def terminate(msg)
        puts "BUILDFILE HAS TERMINATED: " + msg if msg != nil && msg.class.name == "String"
        puts "BUILDFILE HAS TERMINATED." if msg == nil || msg.class.name != "String"
        puts "Builder shutting down..."
        exit(1)
    end
    
    def launch(output)
        unless output.class.name == "Output"
             puts "Launch function needs an output object."
             puts "Builder shutting down..."
             exit(1)
        end
        puts "Launching the program with this path: '#{output.path_to_output}'..."
        unless system("#{output.path_to_output}")
            puts "Failed to launch the program or script with this path: '#{output.path_to_output}'."
            puts "Builder shutting down..."
            exit(1)
       end
        puts "Launched the program or script with this path: '#{output.path_to_output}'."
    end
    
    def run(path)
        failed_to_run = false
        unless path.class.name == "String"
            puts "The 'run' function requires a path to be string."
            exit(1)
        end
        puts "Running the program or script with this path: '#{path}'..."
        unless system("./#{path}")
            unless @builder.allow_extern_exec
             puts "Failed to run the program or script with this path: '#{path}'."
             failed_to_run = true
            else
             failed_to_run = false
             unless system("#{path}")
                puts "Failed to run the program or script with this path: '#{path}'."
                failed_to_run = true
             end
            end
        end
        puts "Ran the program or script with this path: '#{path}'." unless failed_to_run
    end
    
    def format(string)
        unless string.class.name == "String"
            puts "format function needs a string."
            puts "Builder shutting down..."
            exit(1)
        end
        i = 1
        outstring = " "
        outstring[0] = string[0]
        while i < string.length
            outstring += string[i]
            outstring += '__' if string[i] == '_'
            i+=1
        end
        i = 0
        while i < outstring.length
           string << " " if i >= string.length
           string[i] = outstring[i]
           i+=1
        end
    end
end

class BuildObject
    attr_reader :array
    attr_reader :type
    def initialize(stuff)
     @array = stuff
     @type = ""
    end
end

class Files < BuildObject
    def initialize(files)
      super files
      @type = "files"
    end
end

class Url < BuildObject
    def initialize(urls)
        super urls
        @type = "url"
    end
end

class Sources < BuildObject
    def initialize(sources)
        super sources
        @type = "sources"
    end
end

class Compiler < BuildObject
    def initialize(flags)
        super flags
        @type = "compiler"
    end
end

class Linker < BuildObject
    def initialize(flags)
        super flags
        @type = "linker"
    end
end

class Archiver < BuildObject
    def initialize(flags)
        super flags
        @type = "archiver"
    end
end

class Libraries < BuildObject
    def initialize(flags)
        super flags
        @type = "libraries"
    end
end

class Library_names < BuildObject
    def initialize(flags)
        super flags
        @type = "library_names"
    end
end

class Frameworks < BuildObject
    def initialize(flags)
        super flags
        @type = "frameworks"
    end
end

class Path < BuildObject
    def initialize(path)
        super path
        @type = "path"
    end
end

class Toolchain < BuildObject
    def initialize(input)
        super input
        @type = "toolchain"
    end
end

class Output < BuildObject
    attr_accessor :path_to_output
    attr_accessor :output_dylibs
    attr_accessor :output_libs
    def initialize(input)
        super input
        @type = "output"
        @path_to_output = ""
        @output_dylibs = []
        @output_libs = []
    end
end

class Subproject < BuildObject
    attr_accessor :outputs
    attr_accessor :paths
    def initialize(input)
        super input
        @type = "subproject"
        @outputs = nil        
        @paths = nil
    end
end

class GetOS
    #https://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on
    def is_windows?
        true if RUBY_PLATFORM =~ /win32|cygwin|mswin|mingw|bccwin|wince|emx/
    end
    
    def is_mac?
        true if RUBY_PLATFORM =~ /darwin/
    end
    
    def is_linux?
        true if RUBY_PLATFORM =~ /linux/
    end
end

class Builder
 attr_reader :version
 attr_reader :allow_extern_exec
 attr_reader :allowed_external_function
 attr_accessor :buildfile_error_string
 attr_accessor :download_project
 attr_accessor :force_update
 attr_accessor :url_to_src
 attr_accessor :url_to_buildfile
 attr_reader :path_to_subproject
 

 def get_ninja(project)
     init = false
     init = true if File.exist?("#{get_path('ninja')}") || @ninja_path != nil
     puts "Downloading Ninja to #{get_path('project')}.build/ninja..." unless init
     if @OS.is_windows?
         ninja_url = "https://github.com/ninja-build/ninja/releases/download/v1.10.0/ninja-win.zip"
     end
     if @OS.is_mac?
         ninja_url = "https://github.com/ninja-build/ninja/releases/download/v1.10.0/ninja-mac.zip"
     end
     if @OS.is_linux?
         ninja_url = "https://github.com/ninja-build/ninja/releases/download/v1.10.0/ninja-linux.zip"
     end
     ninja_url = ninja_url unless init
     ninja = URI.parse(ninja_url).read unless init
     Dir.mkdir("#{get_path('project')}") unless File.exist?("#{get_path('project')}")
     Dir.mkdir("#{get_path('project')}.build") unless File.exist?("#{get_path('project')}/.build")
     Dir.mkdir("#{get_path('project')}.build/#{project}") unless File.exist?("#{get_path('project')}/.build/#{project}")
     Dir.mkdir("#{get_path('project')}.build/ninja") unless File.exist?("#{get_path('project')}/.build/ninja")
     Dir.mkdir("#{get_path('ninja')}") unless File.exist?("#{get_path('ninja')}")
     file = File.new("#{get_path('ninja')}ninja.zip","wb") unless init
     file.write(ninja) unless init
     if File.exist?("#{get_path('ninja')}ninja.zip")
       Zip::File.open("#{get_path('ninja')}ninja.zip") do |zipfile|
           zipfile.each do |entry|
               unless File.exist?("#{get_path('ninja')}#{entry.name}")
                   zipfile.extract(entry, "#{get_path('ninja')}#{entry.name}")
               end 
           end  
       end
     end
     begin
      FileUtils.remove_file "#{get_path('ninja')}ninja.zip" if File.exist?("#{get_path('ninja')}ninja.zip")
      rescue
     end
     @ninja_path = "#{get_path('ninja')}ninja" if @ninja_path == nil && !@OS.is_windows?
     @ninja_path = "#{get_path('ninja')}ninja.exe" if @ninja_path == nil && @OS.is_windows?
     puts "Downloaded Ninja to #{@ninja_path.chomp('/ninja')}." if !init && !@OS.is_windows?
     puts "Downloaded Ninja to #{@ninja_path.chomp('/ninja.exe')}." if !init && @OS.is_windows?  
 end
 
 def get_root_dir_name2(base_name) 
    i = 0
    j = 0
    x = 0
    root_dir_name = ""
    while i < base_name.length 
      j+=1 if base_name[i] == '/' 
      i+=1
    end
    x = j
    i = 0
    j = 0
    while i < base_name.length 
      j+=1 if base_name[i] == '/' 
      i+=1
     break if j == x 
    end
    while i < base_name.length  
      root_dir_name += base_name[i]
      i+=1
    end
    return root_dir_name
  end
 
def get_root_dir_name(base_name) 
    i = 0
    j = 0
    x = 0
    root_dir_name = ""
    while i < base_name.length 
      break if base_name[i] == '/' 
      i+=1
    end
    x = i
    i = 0
    while i < x  
      root_dir_name += base_name[i]
      i+=1
    end
    return root_dir_name
  end
 
def get_src(url_to_src,project)
     init = false
     init = true if File.exist?("#{get_path('project')}#{project}_src")
     puts "Downloading project: #{project} to #{get_path('project')}#{project}_src..." unless init
     src = URI.parse(url_to_src).read unless init
     Dir.mkdir("#{get_path('project')}#{project}_src") unless File.exist?("#{get_path('project')}#{project}_src")
     file = File.new("#{get_path('project')}#{project}_src/#{project}_src.zip","wb") unless init
     file.write(src) unless init
     if File.exist?("#{get_path('project')}#{project}_src/#{project}_src.zip")
         Zip::File.open("#{get_path('project')}#{project}_src/#{project}_src.zip") do |zipfile|
             zipfile.each do |entry|
                 unless File.exist?("#{get_path('project')}#{project}_src/#{entry.name}")
                     begin
                      zipfile.extract(entry, "#{get_path('project')}#{project}_src/#{entry.name}") 
                     end
                 end
             end
         end
     end
     begin
         FileUtils.remove_file "#{get_path('project')}/#{project}_src/#{project}_src.zip" if File.exist?("#{get_path('project')}/#{project}_src/#{project}_src.zip")
         rescue
     end
     path = "#{get_path('project')}#{project}_src"
     Dir.each_child(path){ |entry|
        path = path + "/" + entry if Dir.exist?( path + "/" + entry )
     }
     puts "Downloaded #{project} to #{path}." unless init
     @path_to_subproject  = path + "/"
     @buildfile.filename = path + "/" + @buildfile.filename
 end
 
 def setup(output,dest_name,dest_dir)
     dest_path = get_path_for_functions(dest_dir) + dest_name + "/"
     Dir.mkdir get_path_for_functions(dest_dir) + dest_name unless File.exist? get_path_for_functions(dest_dir) + dest_name
     FileUtils.copy output.path_to_output, dest_path
     exe = output.path_to_output.split("/")
     exe = exe[exe.length-1]
     output.output_dylibs.each { |dylib|   
         lib = dylib.split("/")
         lib = lib[lib.length-1]
         FileUtils.copy dylib, dest_path
         if ( @OS.is_mac? )
             unless system("install_name_tool -change #{dylib} @loader_path/#{lib} #{dest_path + exe}")
                 puts "Failed to use the install_name_tool on the program with this path: #{dest_path + exe}."
                 puts "Builder shutting down..."
                 exit(1)
             end    
         end
         if ( @OS.is_linux? )
             unless system("chrpath -r $ORIGIN/#{lib} #{dest_path + exe}")
                 puts "Failed to use chrpath on the program with this path: #{dest_path + exe}."
                 puts "Builder shutting down..."
                 exit(1)
             end   
         end
     } 
 end
 
 def move(src_file,src_dir,dest_dir)
     src_dir = get_path_for_functions(src_dir)
     src_path = src_dir + src_file
     dest_path = get_path_for_functions(dest_dir)
     FileUtils.move src_path, dest_path
 end
 
 def copy(src_file,src_dir,dest_dir)
     src_dir = get_path_for_functions(src_dir)
     src_path = src_dir + src_file
     dest_path = get_path_for_functions(dest_dir)
     FileUtils.copy src_path, dest_path
 end
 
 def clean(dirname)
     return nil if dirname == "script"
     return nil if dirname == "resources"
     return nil if dirname == "working"
     return nil if dirname == "output"
     FileUtils.remove_dir get_path(dirname) if File.exist?(get_path(dirname))
 end
 
 def chdir(dirname)
     if dirname == "working" && @working != nil
      Dir.chdir @working
      return
     end
     Dir.chdir get_path_for_functions(dirname)
 end
 
 def get_path_for_functions(dirname)
     return nil if dirname == "script"
     return nil if dirname == "ninja"
     return nil if dirname == "ninja_program"
     return nil if dirname == "download_project_ver_files"
     return get_path(dirname)
 end
 
 def get_path(dirname)
     @working = Dir.pwd + "/" if @working == nil
     path_to_resources = @path_to_subproject
     path_to_resources = Dir.pwd + "/" if path_to_resources == nil
     path_to_project_directory = @superproject + @buildfile.fileinfo["project"] + "/" unless @superproject == nil
     path_to_project_directory = @buildfile.fileinfo["project"] + "/" if @superproject == nil
     path_to_build_directory = path_to_project_directory + ".build/#{@buildfile.fileinfo['project']}/"
     path_to_download_project_ver_files = path_to_project_directory + ".build/#{@buildfile.fileinfo['project']}/download_project_ver_files/"
     path_to_build_directory = path_to_project_directory + ".build/#{@buildfile.fileinfo['project']}/windows/" if @OS.is_windows?
     path_to_build_directory = path_to_project_directory + ".build/#{@buildfile.fileinfo['project']}/mac/" if @OS.is_mac?
     path_to_build_directory = path_to_project_directory + ".build/#{@buildfile.fileinfo['project']}/linux/" if @OS.is_linux?
     path_to_ninja_directory = path_to_project_directory + ".build/ninja/windows/" if @OS.is_windows?
     path_to_ninja_directory = path_to_project_directory + ".build/ninja/mac/" if @OS.is_mac?
     path_to_ninja_directory = path_to_project_directory + ".build/ninja/linux/" if @OS.is_linux?
     path_to_ninja = @ninja_path
     return path_to_resources if dirname == "resources"
     return @superproject if @superproject != nil && dirname == "output"
     return Dir.pwd + "/" if @superproject == nil && dirname == "output"
     return path_to_project_directory if dirname == "project"
     return path_to_build_directory if dirname == "build"
     return path_to_download_project_ver_files if dirname == "download_project_ver_files"
     return path_to_ninja_directory if dirname == "ninja"
     return path_to_ninja.chomp("ninja") if dirname == "ninja_program"
     return Dir.pwd + "/" if dirname == "working"
     return File.expand_path(__FILE__).chomp("builder.rb") if dirname == "script"
     nil
 end
 
 def process_build_options_string(options)
     i = 0
     j = 0
     state = false
     string = ""
     options += "   "
     while i < options.length-2
         j+=1 if options[i] == '_'
         state = true if j > 3
         j = 1 if j > 3
         state = true if options[i+1] != '_'
         string += options[i] if j == 0
         string += ' ' if j == 1 && state
         string += '-' if j == 2 && state
         string += '_' if j == 3 && state
         j = 0 if state
         state = false if state
     i+=1
     end
     string
 end
 
 def initialize(ninja_path,selected_build,build_options,superproject,path_to_subproject,url_to_buildfile,allow_extern_exec,download_project,local_subprojects_force,global_subprojects_force,output_directory,force_update,allowed_external_function)
     #init builder
     @OS = GetOS.new
     @version = "1.5.02"
     @buildfile_error_string = nil
     @selected_build = selected_build
     build_options = process_build_options_string(build_options) unless build_options == nil
     @build_options = build_options.split unless build_options == nil
     @build_options = Array.new if build_options == nil
     @superproject = superproject
     @url_to_src = nil
     @url_to_buildfile = url_to_buildfile
     @allow_extern_exec = allow_extern_exec
     @allowed_external_function = allowed_external_function
     @download_project = download_project
     @local_subprojects_force = local_subprojects_force
     @global_subprojects_force = global_subprojects_force
     @output_directory = output_directory
     @force_update = force_update
     @path_to_subproject = path_to_subproject
     @ninja_path = ninja_path
     @ninjafile = nil
     @output_object_hash = Hash.new
 end
 
 def build_subproject(name,paths)
     options2 = {}
     if paths.array.length < 3
         puts "Subproject needs a string, a path and a build options string."
         exit(1)
     end
     i = 0
     while i < paths.array.length
         string = nil
         string = @buildfile.get_string(paths.array[0]) if paths.array[0].class.name == "String"
         if string != nil && string != "local" && string != "global"
             puts 'Subproject objects must start with the string "local" or "global."'
             exit(1)
         end
         if i == 1 && paths.array[i].class.name != "Files" && paths.array[i].class.name != "Url"
             puts "Project needs path given via a files object or a url object."
             exit(1)
         end
         if i == 2 && ( paths.array[i] != nil && paths.array[i].class.name != "String")
             puts "Build options need to be a string."
             exit(1)
         end
         if i == 2
             options_string = paths.array[2]
             options_string = options_string.split unless options_string == nil
             options_string = Array.new if options_string == nil
             OptionParser.new do |opts|
                 opts.banner = "Usage: builder [options]"
                 opts.on("-b", "--build_select=build", "Select the build to run in the buildfile.") do |b|
                     options2[:selected_build] = b
                 end
                 opts.on("-i", "--input_build_options=input", "Give a string containing command-line options(in options string format) to be used as input for the running build. Format example: '-t gcc' is to be input as '__t_gcc'. One underscore is space, two is '-', three is '_', four is reset.") do |i|
                     options2[:build_options] = i
                 end
                 opts.on("-d", "--download_project", "Download the project from the given buildfile, build with the given buildfile.") do |d|
                     options2[:download_project] = d
                 end
                 opts.on("-a", "--allow_extern_exec", "Allow execution of external(outside working directory) programs or scripts via the run function.") do |a|
                     options2[:allow] = a
                 end
                 opts.on("-e", "--external_move_or_copy", "Allow external move or copy, where the destination can be outside of the output directory, via the external function.") do |e|
                     options2[:external_move_or_copy] = e
                 end
                 opts.on("-l", "--local_subprojects_force", "Force all subprojects to be local.") do |l|
                     options2[:local_subprojects_force] = l
                 end
                 opts.on("-g", "--global_subprojects_force", "Force all subprojects of this project to be global.") do |g|
                     options2[:global_subprojects_force] = g
                 end
                 opts.on("-p", "--project_force_update", "Force the current project to update.") do |p|
                     options2[:force_update] = p
                 end
                 opts.on("-h", "--help", "Prints help.") do
                     puts opts
                     exit
                 end
             end.parse!(options_string)
             project = nil
             project = get_path("project") if paths.array[0] == "local" || @local_subprojects_force
             project = nil if @global_subprojects_force
             project = @output_directory if project == nil && @output_directory
             options2[:local_subprojects_force] = true if @local_subprojects_force
             options2[:global_subprojects_force] = false if @local_subprojects_force
             options2[:allow] = false unless @allow_extern_exec
             url_to_buildfile = nil
             url_to_buildfile = paths.array[1].array[0] if paths.array[1].class.name == "Url"
             options2[:filename] = paths.array[1].array[0]
             ext = paths.array[1].array[0].split("/")
             path = paths.array[1].array[0].chomp(ext[ext.length-1])
             builder = Builder.new @ninja_path, options2[:selected_build], options2[:build_options], project, path, url_to_buildfile, options2[:allow], options2[:download_project], options2[:local_subprojects_force], options2[:global_subprojects_force], @output_directory, options2[:force_update], options2[:external_move_or_copy]
             puts "Building subproject: '#{name}' with buildfile: '#{options2[:filename]}'..."
             output_objects, output_paths = builder.run options2[:filename]
         end
         i+=1
         break if i >= 3
     end
     paths.outputs = output_objects
     paths.paths = output_paths
 end
 
 def build(name,output,project)
     i = 0
     @ninjafile = BuildNinjaFile.new self, @buildfile, @buildfile.fileinfo["project"], @superproject, @path_to_subproject, @ninja_path if @ninjafile == nil
     unless output.type == "output"
         puts "Object is not output. Only output objects can be used with 'build'."
         exit(1)
     end
    @output_object_hash["#{name}"] = @ninjafile.process_output output, name
 end
 
 def run_a_buildfile(buildfile)
     the_build = ""
     if buildfile.buildstring.length == 0
      puts "No builds in buildfile: '#{buildfile.filename}'."
      exit(1)
     end
     puts "Building project: '#{buildfile.fileinfo['project']}'..."
     puts "Running buildfile: '#{buildfile.filename}'..."
     buildfile.default_build = nil unless @selected_build == nil
     unless buildfile.default_build == nil
      the_build = buildfile.default_build
     else
      if buildfile.buildstring.length == 1 || @selected_build != nil
         buildfile.buildstring.each { |key, value|  
             the_build = key
         }
         the_build = @selected_build unless @selected_build == nil
      else
       puts "Multiple builds detected, select one."
       buildfile.buildstring.each { |key, value|
           puts "Detected build: #{key}"
       }
       print "Type in the name of the build you wish to select: "
       the_build = gets.chomp
      end
     end
     unless buildfile.buildstring.has_key?(the_build)
         puts "The name of the build you have given is invalid and does not exist in this buildfile."
         exit(1) 
     end
     puts "Running build: '#{the_build}'..."
     #puts buildfile.buildstring[the_build]
     eval buildfile.buildstring[the_build]
     puts "Done building project: '#{buildfile.fileinfo['project']}'."
 end

 def run(filename)
     @buildfile = Buildfile.new(self)
     @buildfile.parse_file(filename)
     run_a_buildfile(@buildfile)
     output_paths = Hash.new
     output_paths["project"] = get_path("project")
     output_paths["resources"] = get_path("resources")
     output_paths["build"] = get_path("build")
     return @output_object_hash, output_paths
 end

 def kill_dir(dir)
  Dir.each_child(dir){ |entry|
     next if entry[0] == '.'
     unless Dir.exist?(dir + "/" + entry)
        FileUtils.remove_file dir + "/" + entry
     end
     kill_dir(dir + "/" + entry) if Dir.exist?(dir + "/" + entry)
  }
  FileUtils.remove_dir dir
 end
end

class Buildfile
    attr_reader :fileinfo
    attr_accessor :filename
    attr_reader :buildstring
    attr_accessor :default_build
    
    def is_space?(s)  
     return true if s =~ /^\s*$/
     false
    end
    
    def is_symbol?(c)
       return true if c == '('
       return true if c == ')'
       return true if c == ','
       return true if c == '+'
       return true if c == '-'
       return true if c == '*'
       return true if c == '/'
       return true if c == '%'
       return true if c == ':'
       return true if c == '='
       return true if c == '>'
       return true if c == '<'
       return true if c == '&'
       return true if c == '|'
       if @balance == 0
        return true if c == '.'
       end
       false
    end
    
    def is_string?(s)
      return true if s[0] == '"' && s[s.length-1] == '"'
      false
    end
    
    def get_string(s)
        t = s.split('"')
        t.each { |e|
           return e if e != ""
        }
    end
    
    def compare_versions(min,max,ver)
        i = 0
        j = 0
        k = 0
        return true if min == nil || max == nil || ver == nil
        while i < ver.length
         return false if k >= max.length
         i+=1 if ver[i] == "."
         j+=1 if min[j] == "."
         k+=1 if max[k] == "."
         return false if ver[i].to_f < min[j].to_f
         return false if ver[i].to_f > max[k].to_f
         i+=1
         j+=1 if j+1 < min.length
         k+=1
        end
        true
    end
    
    def parse_include(line)
    path = ""
     unless @current_build == nil
         puts "build #{@current_build} is not ended."
         exit(1)
     end
     unless is_string?(line[1]) && is_string?(line[3])
         puts "On line: #{@line_number}, expected string."
         exit(1)
     end
     unless line[2] == "from"
         puts "On line: #{@line_number}, expected 'from'."
         exit(1)
     end
     unless @fileinfo["init"] == true
         puts "Builder needs all file information values in a buildfile before an include, and will not process an include without them."
         exit(1)
     end
      path = @builder.get_path_for_functions(get_string(line[3])) + get_string(line[1])
      @includes.push path
    end
    
    def parse_build(line)
        unless @scope_stack.length == 0
            puts "On line: #{@line_number}, not ended with '#{@scope_stack[@scope_stack.length-1]}'."
            exit(1)
        end
       if @fileinfo["init"] == false || @fileinfo["project"] == nil || @fileinfo["project_version"] == nil ||
          @fileinfo["buildfile_version"] == nil
         puts "Error: file information is not initialized."
         puts "Missing either project, project_version, or buildfile_version."
         puts "Missing: 'project' value. Project name not set." if @fileinfo["project"] == nil
         puts "Missing: 'project_version' value. Project version not set." if @fileinfo["project_version"] == nil
         puts "Missing: 'buildfile_version' value. Buildfile version not set." if @fileinfo["buildfile_version"] == nil
         puts "Builder needs all file information values in a buildfile, and will not process a buildfile without them."
         exit(1)
       end
       unless compare_versions @buildfile_version_min,@buildfile_version_max,@fileinfo["buildfile_version"]
         puts "Unsupported buildfile version: #{@fileinfo['buildfile_version']}."
         puts "Builder version: #{@builder.version}, only supports buildfile versions between: #{@buildfile_version_min}, and #{@buildfile_version_max}."
         exit(1)
       end
       unless @url_to_buildfile == nil
         puts "build cannot occur before 'url_to_src'."
         exit(1)
       end
       @builder.get_ninja @fileinfo["project"]
       unless @current_build == nil
          puts "build #{@current_build} is not ended."
          exit(1)
       end
       @current_build = line[1]
       puts "Processing build: #{@current_build}..."
       unless @buildstring.has_key?(@current_build)
           @buildstring[@current_build] = ""
           @buildstring[@current_build] += "is_win = @OS.is_windows?\n"
           @buildstring[@current_build] += "is_mac = @OS.is_mac?\n"
           @buildstring[@current_build] += "is_linux = @OS.is_linux?\n"
       end
       @scope_stack.push("build")
    end
    
    def parse_end(line)
        string = ""
        @scope_stack.pop if @scope_stack[@scope_stack.length-1] == "build"
        if @scope_stack.length >= 1
           unless line[1] == @scope_stack[@scope_stack.length-1]
            puts "On line: #{@line_number}, not ended with '#{@scope_stack[@scope_stack.length-1]}'."
            exit(1)
           end
           string += "end"
           if @scope_stack[@scope_stack.length-1] == "options"
             string += ".parse!(@build_options)"
           end
           string += "\n"
           @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
           @scope_stack.pop
           return
        end
        unless line[1] == "build"
            puts "On line: #{@line_number}, not ended with 'build'."
            exit(1)
        end
        unless @current_build != nil
            puts "On line: #{@line_number}, there is no current build."
            exit(1)
        end
        @current_build = nil
    end
    
    def parse_default(line)
        unless @current_build == nil
            puts "On line: #{@line_number}, default can not be used in a build."
            exit(1)
        end
        @default_build = line[1]
    end
    
    def parse_get(line)
        string = ""
        unless @options_hash[line[1]]
           puts "On line: #{@line_number}, not an option variable."
           exit(1)
        end
        string += "#{line[1]} = @#{line[1]}\n"
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_function(line)
        i = 1
        j = true
        string = String.new
        string += "BuildFunctions.new(self)."
        string += line[0]
        string += "("
        if line[i] == "("
            i+=1
            while line[i] != ")"
                unless j 
                    j = true if line[i] == ","
                    string += line[i] if j
                    i+=1 if j
                end
                unless j
                    puts "On line: #{@line_number}, there is no ','."
                    exit(1)
                end
                while line[i] == '('
                    i+=1
                end
                if is_string?(line[i])
                    string += line[i]
                    else
                    string += line[i].downcase
                end
                while line[i] == ')'
                    i+=1
                end
                i+=1
                j = false
            end
            else
            puts "On line: #{@line_number}, there is no '('."
            exit(1)
        end
        string += ")\n"
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_run_function(line)
        i = 1
        string = String.new
        string += "BuildFunctions.new(self)."
        string += line[0]
        string += "("
        if line[i] == "("
            i+=1
            while line[i] != ")"
                while line[i] == '('
                    i+=1
                end
                if is_string?(line[i])
                    string += line[i]
                    else
                    string += line[i].downcase
                end
                while line[i] == ')' 
                    i+=1
                end
                i+=1
            end
            else
            puts "On line: #{@line_number}, there is no '('."
            exit(1)
        end
        string += ")\n"
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil 
    end
    
    def parse_on(line)
        i = 2
        j = true
        k = 0
        string = String.new
        string += "opts.on("
        if line[i] == "(" 
            i+=1
            while line[i] != ")"
                unless j
                    j = true if line[i] == ","
                    string += line[i] if j
                    i+=1 if j
                end
                unless j
                    puts "On line: #{@line_number}, there is no ','."
                    exit(1)
                end
                unless is_string?(line[i])
                    puts "On line: #{@line_number}, expected string."
                    exit(1)
                end
                string += line[i]
                i+=1
                j = false
                k+=1
                if k == 4
                   puts "On line: #{@line_number}, too many arguments to an on statement."
                   exit(1)
                end
            end
            else
            puts "On line: #{@line_number}, there is no '('."
            exit(1)
        end
        string += ")do |i|\n"
        string += "@#{line[1]} = i\n"
        string += "end\n"
        @options_hash = Hash.new if @options_hash == nil
        @options_hash[line[1]] = true
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_options(line)
     string = String.new
     if @scope_stack[@scope_stack.length-1] == "options"
       puts "On line: #{@line_number}, options can not exist within an options block."
       exit(1)
     end
     string += "OptionParser.new do |opts|\n"
     string += "opts.banner = 'Usage: builder -i [build_options]'\n"
     string += "opts.on('-h', '--help', 'Prints help.') do\n"
     string += "puts opts\n"
     string += "exit\n"
     string += "end\n"
     @scope_stack.push("options")
     @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_object(line)
       i = 2
       j = true
       string = String.new
       string += "#{line[1].downcase} = "
       string += line[0].capitalize
       string += ".new ["
       if line[i] == "("
        i+=1
        while line[i] != ")"
         unless j
          j = true if line[i] == "," || is_symbol?(line[i])
          string += line[i] if j
          i+=1 if j
         end
         unless j
          puts "On line: #{@line_number}, there is no ','."
          exit(1)
         end
         if is_string?(line[i])
          string += line[i]
         else
          string += line[i].downcase
         end
         i+=1
         j = false
        end
       else
        puts "On line: #{@line_number}, there is no '('."
        exit(1)
       end
       string += "] \n"
       string += "build '#{line[1]}', #{line[1].downcase}, \"#{@fileinfo['project']}\"\n" if line[0] == "output"
       string += "@ninjafile.write_file\n" if line[0] == "output"
       string += "@ninjafile.run_ninja('#{line[1]}')\n" if line[0] == "output"
       string += "build_subproject '#{line[1]}', #{line[1].downcase}\n" if line[0] == "subproject"
       @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_return_output(line)
     string = String.new
     string += "@output_object_hash['#{line[1]}'] = #{line[1].downcase}\n"
     @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_grab(line)
     string = String.new
     unless line[2] == "from"
        puts "On line: #{@line_number}, expected 'from'."
        exit(1)
     end
     string += "#{line[1].downcase} = #{line[3].downcase}.outputs['#{line[1]}']\n"
     @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_make(line)
       string = String.new
       unless line[1] == "filepath"
           puts "On line: #{@line_number}, expected 'filepath'."
           exit(1)
       end
       unless line[3] == "from"
           puts "On line: #{@line_number}, expected 'from'."
           exit(1)
       end
       unless line[5] == "to"
           puts "On line: #{@line_number}, expected 'to'."
           exit(1)
       end
       unless is_string?(line[4]) && is_string?(line[6])
           puts "On line: #{@line_number}, expected string."
           exit(1)
       end
       if line.length == 8
        string += "#{line[2].downcase} = get_path_for_functions(#{line[4]}) + #{line[6]}\n"
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
        return
       end
       unless line[7] == "from" 
        puts "On line: #{@line_number}, expected 'from'."
        exit(1)
       end
       string += "#{line[2].downcase} = #{line[8].downcase}.paths[#{line[4]}] + #{line[6]}\n"
       @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_get_file_exist(line)
     #get_file_exist 'var' for file 'path'.
     string = String.new
     unless line[2] == "for"
        puts "On line: #{@line_number}, expected 'for'."
        exit(1)
     end
     unless line[3] == "file"
        puts "On line: #{@line_number}, expected 'file'."
        exit(1)
     end
     string += "#{line[1]} = File.exist?(#{line[4]})\n"
     @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_block(line)
        i = 2
        string = String.new
        operator_hash = Hash.new
        operator_hash["=="] = true
        operator_hash["!="] = true
        operator_hash[">="] = true
        operator_hash["<="] = true
        operator_hash["&&"] = true
        operator_hash["||"] = true
        operator_hash["<"] = true
        operator_hash[">"] = true
        string += line[0]
        if line[1] != "("
          puts "On line: #{@line_number}, there is no '('."
          exit(1)
        end
        while line[i] == '('
            i+=1
        end
        string += " #{line[i]} "
        i+=1
        while line[i] == ')'
            i+=1
        end
        if line[i] == "." && line[i-1] == ")"
         string += "\n"
         @scope_stack.push(line[0])
         @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
         return
        end
        while operator_hash[line[i]] || operator_hash[line[i]+line[i+1]]
        unless operator_hash[line[i]]
            unless operator_hash[line[i]+line[i+1]]
                puts "On line: #{@line_number}, expected operator."
                exit(1)
            else
             string += line[i]+line[i+1]
             i+=2
            end
        else
         if operator_hash[line[i]+line[i+1]]
            string += line[i]+line[i+1]
            i+=2
          else
           string += line[i]
           i+=1
         end
        end
        while line[i] == '('
            i+=1
        end
        string += " #{line[i]}"
        i+=1
        while line[i] == ')' 
            i+=1 
        end
        string += " "
        break if i > line.length || i+1 > line.length || i+2 > line.length
        end
        string += "\n"
        i-=1
        if line[i] != ")"
           puts "On line: #{@line_number}, expected ')'."
           exit(1)
        end
        @scope_stack.push(line[0])
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_var(line)
        string = ""
        if line[2] == ':' && line[3] == '='
            string = "#{line[1]} = #{line[4]}\n"
            else
            puts "On line: #{@line_number}, expected ':='."
            exit(1)
        end
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_string(line)
        string = ""
        if line[2] == ':' && line[3] == '='
          if is_string?(line[4])
          string = "#{line[1]} = #{line[4]}\n"
          else
          puts "On line: #{@line_number}, expected string."
          exit(1)
          end
        else
         puts "On line: #{@line_number}, expected ':='."
         exit(1) 
        end
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil 
    end
    
    def parse_bool(line)
        string = ""
        if line[2] == ':' && line[3] == '='
            if line[4] == "true" || line[4] == "false"
                string = "#{line[1]} = #{line[4]}\n"
                else
                puts "On line: #{@line_number}, expected boolean."
                exit(1)
            end
            else
            puts "On line: #{@line_number}, expected ':='."
            exit(1)
        end
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
    def parse_float(line)
        i = 4
        string = ""
        if line[2] == ':' && line[3] == '='   
            while line[i] == '('
                i+=1
            end
            unless is_string?(line[i])
                string = "#{line[1]} = #{line[i].to_f}\n"
                else
                puts "On line: #{@line_number}, expected float."
                exit(1)
            end
            else
            puts "On line: #{@line_number}, expected ':='."
            exit(1)
        end
        @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
    end
    
     def parse_eval(line)
         i = 6
         string = ""
         operator_hash = Hash.new
         operator_hash["+"] = "+"
         operator_hash["-"] = "-"
         operator_hash["*"] = "*"
         operator_hash["/"] = "/"
         operator_hash["%"] = "%"
         if line[2] == ':' && line[3] == '='
             string = "#{line[1]} = #{line[4]}"
             unless operator_hash.has_key?(line[5])
                puts "On line: #{@line_number}, expected operator."
                exit(1)
             end
             string += line[5]
             while line[i] == '('
                 i+=1
             end
            string += "#{line[1]} = #{line[i]}\n"
         else
             puts "On line: #{@line_number}, expected ':='."
             exit(1)
         end
         @buildstring[@current_build] += string unless @buildstring[@current_build] == nil
     end
    
    def parse_url_to_src(line)
        if line.length < 4
            puts "On line: #{@line_number}, error: empty line."
            exit(1)
        end
        unless is_string?(line[3]) 
            puts "On line: #{@line_number}, expected string."
            exit(1)
        end
        if line[1] == ':' && line[2] == '='
           @builder.url_to_src = get_string(line[3]) if @builder.url_to_src  == nil
          else
           puts "On line: #{@line_number}, expected ':='."
           exit(1)
        end
    end
    
    def parse_values(line)
      i = 3
      if line.length < 2
        puts "On line: #{@line_number}, error: empty line."
        exit(1)
      end
      if line[1] == ':' && line[2] == '='
          if is_string?(line[3])
           unless @fileinfo["init"]
            @fileinfo[line[0]] = get_string(line[3])
           else
           @project_version_max = get_string(line[3]) if line[0] == "project_version" && @downloaded
            unless @fileinfo[line[0]] == get_string(line[3])
                if line[0] == "project"
                 j = 0
                 test = get_string(line[3])
                 while j < test.length
                     test[j] = "_" if is_space?(test[j])
                     j+=1
                 end
                end
                unless test == @fileinfo[line[0]]
                 if @downloaded && line[0] == "project_version"
                   #do nothing
                 else
                  puts "On line: #{@line_number}, expected '#{@fileinfo[line[0]]}', not #{line[3]}."
                  exit(1)
                end
               end
            end
           end
          else
           puts "On line: #{@line_number}, expected string."
           exit(1)
          end
          puts "File information for #{line[0]} is: #{@fileinfo[line[0]]}."
          @parsed_values += 1
          @fileinfo["init"] = true if @parsed_values == 3
          puts "File information is initialized." if @fileinfo["init"] && @parsed_values <= 3
          if @fileinfo["init"]
          j = 0
           while j < @fileinfo["project"].length
             @fileinfo["project"][j] = "_" if is_space?(@fileinfo["project"][j])   
             j+=1
          end
          puts "Project is: '#{@fileinfo['project']}'."
          end
      else
       puts "On line: #{@line_number}, expected ':='."
       exit(1)
      end
    end
    
    def initialize(builder)
        @OS = GetOS.new
        @builder = builder
        @downloaded = false
        @save_url_to_buildfile = nil
        @includes = Array.new
        @done_includes = Hash.new
        @buildstring = Hash.new
        @default_build = nil
        @current_build = nil
        @parsed_values = 0
        @buildfile_version_max = "1.5"
        @buildfile_version_min = "1.0"
        @project_version_max = nil
        @filename = nil
        @fileinfo = Hash.new
        @fileinfo["init"] = false
        @fileinfo["project"] = nil
        @fileinfo["project_version"] = nil
        @fileinfo["buildfile_version"] = nil
        @scope_stack = Array.new
        @parse_hash = Hash.new
        @parse_hash["project"] = method(:parse_values)
        @parse_hash["project_version"] = method(:parse_values)
        @parse_hash["buildfile_version"] = method(:parse_values)
        @parse_hash["url_to_src"] = method(:parse_url_to_src)
        @parse_hash["build"] = method(:parse_build)
        @parse_hash["end"] = method(:parse_end)
        @parse_hash["default"] = method(:parse_default)
        @parse_hash["files"] = method(:parse_object)
        @parse_hash["url"] = method(:parse_object)
        @parse_hash["sources"] = method(:parse_object)
        @parse_hash["compiler"] = method(:parse_object)
        @parse_hash["linker"] = method(:parse_object)
        @parse_hash["archiver"] = method(:parse_object)
        @parse_hash["dlinker"] = method(:parse_object)
        @parse_hash["frameworks"] = method(:parse_object)
        @parse_hash["libraries"] = method(:parse_object)
        @parse_hash["library_names"] = method(:parse_object)
        @parse_hash["path"] = method(:parse_object)
        @parse_hash["toolchain"] = method(:parse_object)
        @parse_hash["output"] = method(:parse_object)
        @parse_hash["subproject"] = method(:parse_object)
        @parse_hash["string"] = method(:parse_string)
        @parse_hash["float"] = method(:parse_float)
        @parse_hash["bool"] = method(:parse_bool)
        @parse_hash["var"] = method(:parse_var)
        @parse_hash["eval"] = method(:parse_eval)
        @parse_hash["if"] = method(:parse_block)
        @parse_hash["unless"] = method(:parse_block)
        @parse_hash["while"] = method(:parse_block)
        @parse_hash["options"] = method(:parse_options)
        @parse_hash["on"] = method(:parse_on)
        @parse_hash["get"] = method(:parse_get)
        @parse_hash["return_output"] = method(:parse_return_output)
        @parse_hash["grab"] = method(:parse_grab)
        @parse_hash["make"] = method(:parse_make)
        @parse_hash["get_file_exist"] = method(:parse_get_file_exist)
        @parse_hash["include"] = method(:parse_include)
        @parse_hash["message"] = method(:parse_function)
        @parse_hash["set_buildfile_error_string"] = method(:parse_function)
        @parse_hash["setup"] = method(:parse_function)
        @parse_hash["move"] = method(:parse_function)
        @parse_hash["copy"] = method(:parse_function)
        @parse_hash["move_output"] = method(:parse_function)
        @parse_hash["copy_output"] = method(:parse_function)
        @parse_hash["external"] = method(:parse_function)
        @parse_hash["clean"] = method(:parse_function)
        @parse_hash["clean_output"] = method(:parse_function)
        @parse_hash["remove"] = method(:parse_function)
        @parse_hash["terminate"] = method(:parse_function)
        @parse_hash["launch"] = method(:parse_function)
        @parse_hash["run"] = method(:parse_run_function)
        @parse_hash["change_working_directory_to"] = method(:parse_function)
        @parse_hash["display_working_directory"] = method(:parse_function)
        @parse_hash["format"] = method(:parse_function)
    end
    
    def parse_line(line)
        if @parse_hash.has_key?(line[0])
         @parse_hash[line[0]].call line
        else
         puts "On line: #{@line_number}, unknown word: #{line[0]}." if line[0] != nil
         exit(1)
       end
        unless line[line.length-1] == "."
            puts "On line: #{@line_number}, expected 'end of line'."
            exit(1)
        end
    end
    
    def parse_file(filename)
     @filename = filename if @filename == nil
     puts "Parsing buildfile: '#{filename}', initializing file information..."
     i = 0
     is_string = false
     end_of_line = false
     end_of_line2 = false
     finline = []
     word = ""
     symword = nil
     noline = 0
     @balance = 0
     @line_number = 0
     unless @builder.url_to_buildfile == nil
      begin
       file = StringIO.new(URI.parse(@builder.url_to_buildfile).read, "r")
       #rescue Exception
       #puts "Given URL to buildfile is either invalid or busy."
       #exit(1)
      end
     else
      begin 
       file = File.new(filename,"r")
       rescue Exception
       puts "Given buildfile does not exist."
       exit(1)
      end
     end
     file.each_line do |line|
     @line_number += 1
     if @builder.download_project && !@builder.force_update && @fileinfo["init"] && @downloaded
        if File.exist? @builder.get_path("download_project_ver_files") + @fileinfo["project"]
            @builder.download_project = false
            @downloaded = false
            ver = IO.readlines(@builder.get_path("download_project_ver_files") + @fileinfo["project"], chomp: true)
            @builder.force_update = true if !compare_versions("0.0",ver[0],@fileinfo["project_version"])
            if @builder.force_update
             FileUtils.remove_file @builder.get_path("download_project_ver_files") + @fileinfo["project"] if File.exist?(@builder.get_path("download_project_ver_files") + @fileinfo["project"])
             download_project_ver_file = File.new(@builder.get_path("download_project_ver_files") + @fileinfo["project"],"w")
             download_project_ver_file.write(@fileinfo["project_version"])
             download_project_ver_file.close
             @builder.download_project = true
            end
        end
     end
     if (@downloaded && @project_version_max != nil) || (@builder.force_update && @downloaded) || (@builder.force_update && @builder.download_project)
         if !compare_versions("0.0",@project_version_max,@fileinfo["project_version"]) || (@builder.force_update && @downloaded) || (@builder.force_update && @builder.download_project)
            puts "Updating project '#{@fileinfo['project']}'..." 
            file.close if @builder.url_to_buildfile == nil
            FileUtils.remove_dir "#{@builder.get_path('project')}#{@fileinfo['project']}_src" if File.exist?("#{@builder.get_path('project')}#{@fileinfo['project']}_src")
            @builder.url_to_buildfile = @save_url_to_buildfile
            @project_version_max = nil
            @builder.force_update = false
            @downloaded = false
         end
     end
     if @builder.url_to_buildfile == nil && @builder.download_project
         if @fileinfo["init"] && @builder.url_to_src
             ext = @filename.split("/")
             @filename = ext[ext.length-1]
             @builder.get_ninja @fileinfo["project"]
             @builder.get_src(@builder.url_to_src,@fileinfo["project"])
             Dir.mkdir(@builder.get_path("download_project_ver_files")) unless File.exist?(@builder.get_path("download_project_ver_files"))
             unless File.exist?(@builder.get_path("download_project_ver_files") + @fileinfo["project"])
              download_project_ver_file = File.new(@builder.get_path("download_project_ver_files") + @fileinfo["project"],"w")
              download_project_ver_file.write(@fileinfo["project_version"])
              download_project_ver_file.close
             end
             @save_url_to_buildfile = @builder.url_to_buildfile
             @builder.url_to_buildfile = nil
             puts "Parsing buildfile for downloaded project: '#{filename}'..."
             @filename = filename
             @downloaded = true
             self.parse_file @filename
             return
         end
     end
     unless @builder.url_to_buildfile == nil 
         if @fileinfo["init"] && @builder.url_to_src
          ext = @builder.url_to_buildfile.split("/")
          @filename = ext[ext.length-1]
          @builder.get_ninja @fileinfo["project"]
          @builder.get_src(@builder.url_to_src,@fileinfo["project"])
          @save_url_to_buildfile = @builder.url_to_buildfile
          @builder.url_to_buildfile = nil
          @downloaded = true
          puts "Parsing downloaded buildfile: '#{@filename}'..."
          self.parse_file @filename
          return
         end
     end
     i = 0
     while i < line.length
      c = line[i]
      #puts "Hello:#{c}"
      if c == "@" && !is_string
         puts "On line: #{@line_number}, symbol '@' is not allowed."
         exit(1)
      end
      noline +=1 if noline < 2 && !is_string && c == '/'
      noline = 0 if i == 0 && c != '/'
      noline = 0 if c != '/' && noline == 1
      if noline >= 2
       finline.pop if c == '/'
       i+=1
       next
      end
      @balance+=1 if c == '(' && !is_string
      @balance-=1 if c == ')' && !is_string
      if @balance < 0
          puts "Error: non-balanced: ')'."
          exit(1)
      end
      if c == '.' && @balance == 0 && !is_string
          end_of_line = true
      end
      if is_string && c == '"'
          is_string = false
          c = '\a'
      end
      is_string = true if c == '"'
      c = '"' if c == '\a'
      if is_symbol?(c) && !is_string
       symword = c
      end
     if (!is_space?(c) && !is_symbol?(c)) || is_string
       word = word + c
     end
      if (is_space?(c) && !is_string) || (is_symbol?(c) && !is_string)
          #puts "Hello5:#{c}, is_space?: #{is_space?(c)}, is_symbol?: #{is_symbol?(c)}, is_string: #{is_string}"
          finline.push(word) if finline != nil && word != ""
          if finline.length-1 != 0 && @parse_hash.has_key?(word)
              if finline[0] == "end" && (word == "build" || word == "if" || word == "unless" || word == "while" || word == "options" ||  word == "on")
                  end_of_line2 = true 
                 else
                  puts "On or near line: #{@line_number}, expected 'end of line'."
                  exit(1)
                 end
           end
          if end_of_line2 == true && end_of_line == false
              puts "On or near line: #{@line_number}, expected 'end of line'."
              exit(1)
          end
          end_of_line2 = false
          if symword != nil
           finline.push(symword)
           symword = nil
          end
          word = ""
          if end_of_line
           #puts finline
           #puts @balance
           parse_line(finline)
           finline = []
           end_of_line = false
          end
      end
     i+=1
     end
     end
    file.close
    @done_includes[File.expand_path(filename)] = true
    @includes.each { |an_include|
        next if @done_includes[an_include]
        @done_includes[an_include] = true
        puts "Including buildfile: '#{an_include}'..."
        self.parse_file an_include
    }
     unless @scope_stack.length == 0
        puts "On line: #{@line_number}, not ended with '#{@scope_stack[@scope_stack.length-1]}'."
        exit(1)
     end
    end
end

OptionParser.new do |opts|
    
    opts.banner = "Usage: builder [options]"
    
    opts.on("-v", "--version", "Version of builder.") do |v|
        options[:version] = v
    end
    
    opts.on("-f", "--filename=name", "Filename of the buildfile. Default filename is 'buildfile'.") do |f|
        options[:filename] = f
    end
    
    opts.on("-b", "--build_select=build", "Select the build to run in the buildfile.") do |b|
        options[:selected_build] = b
    end
    
    opts.on("-i", "--input_build_options=input", "Give a string containing command-line options(in options string format) to be used as input for the running build. Format example: '-t gcc' is to be input as '__t_gcc'. One underscore is space, two is '-', three is '_', four is reset.") do |i|
        options[:build_options] = i
    end
    
    opts.on("-u", "--url_to_buildfile=buildfile", "Give a URL to a buildfile for a project to be downloaded and built.") do |u|
        options[:url_to_buildfile] = u
    end
    
    opts.on("-d", "--download_project", "Download the project from the given buildfile, build with the given buildfile.") do |d|
        options[:download_project] = d
    end
    
    opts.on("-a", "--allow_extern_exec", "Allow execution of external(outside working directory) programs or scripts via the run function.") do |a|
        options[:allow] = a
    end
    
    opts.on("-e", "--external_move_or_copy", "Allow external move or copy, where the destination can be outside of the output directory, via the external function.") do |e|
        options[:external_move_or_copy] = e
    end
    
    opts.on("-l", "--local_subprojects_force", "Force all subprojects to be local.") do |l|
        options[:local_subprojects_force] = l
    end
    
    opts.on("-g", "--global_subprojects_force", "Force all subprojects of this project to be global.") do |g|
        options[:global_subprojects_force] = g
    end
    
    opts.on("-o", "--output_directory=output", "Set the output directory(the directory where the project is built), defaults to the current working directory.") do |o|
        options[:output_directory] = o
    end
    
    opts.on("-p", "--project_force_update", "Force the current project to update.") do |p|
        options[:force_update] = p
    end
    
    opts.on("-h", "--help", "Prints help.") do
        puts opts
        exit
    end
    
end.parse!

options[:filename] = "buildfile" if options[:filename] == nil
options[:filename] = options[:url_to_buildfile] unless options[:url_to_buildfile] == nil
options[:output_directory] = options[:output_directory] + "/" unless options[:output_directory] == nil
Dir.mkdir("#{options[:output_directory]}") unless File.exist?("#{options[:output_directory]}") unless options[:output_directory] == nil

builder = Builder.new nil, options[:selected_build], options[:build_options], options[:output_directory], nil, options[:url_to_buildfile], options[:allow], options[:download_project], options[:local_subprojects_force], options[:global_subprojects_force], options[:output_directory], options[:force_update], options[:external_move_or_copy]

if options[:version]
    puts "Builder version: #{builder.version}."
    exit
end

#puts Dir.pwd
#Dir.chdir File.expand_path(__FILE__).chomp "builder.rb"
#puts File.expand_path(__FILE__)

puts "Welcome to Builder."
puts "Builder version: #{builder.version}."
puts "Reading primary buildfile: '#{options[:filename]}'..."
builder.run options[:filename]

