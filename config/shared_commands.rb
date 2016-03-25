# This file should be used to extend the origen command line tool with tasks 
# specific to your application.
# The comments below should help to get started and you can also refer to
# lib/origen/commands.rb in your Origen core workspace for more examples and 
# inspiration.
#
# Also see the official docs on adding commands:
#   http://origen.freescale.net/origen/latest/guides/custom/commands/

# Map any command aliases here, for example to allow origen -x to refer to a 
# command called execute you would add a reference as shown below: 
aliases ={
  "g"  => "generate"
}

# The requested command is passed in here as @command, this checks it against
# the above alias table and should not be removed.
@command = aliases[@command] || @command

case @command

  #when "latpc"
  #  require "#{Origen.root(:testers)}/lib/commands/latpc"
  # Need to see if --compile is included and setup compiler
  when "generate"
  @application_options << ["--compile", "Compile the current pattern or the list"]
  @application_options << ["-v", "--vector_comments", "Add the vector and cycle number to the vector comments"]
  if ARGV.include?('--compile')
    compiler_instance_name = ARGV[ARGV.index('--compile')+1]
    if compiler_instance_name.nil?
      $compiler = :use_app_default
    else
      ARGV.delete(compiler_instance_name) 
      $compiler = compiler_instance_name.to_sym
    end
    ARGV.delete("--compile")
  end
  $_testers_enable_vector_comments = ARGV.delete("-v") || ARGV.delete("--vector_comments")

  when "testers:build"
   require "#{Origen.root!}/lib/commands/build"
    exit 0

  when "testers:run"
   require "#{Origen.root!}/lib/commands/run"
    exit 0


  else
  @plugin_commands << " testers:build   Build a test program from a collection of sub-programs"
  @plugin_commands << " testers:run     Run the last test program generated for the current target"

end 
