module Reduce
using Compat; import Compat.String

#   This file is part of Reduce.jl. It is licensed under the MIT license
#   Copyright (C) 2017 Michael Reed

immutable RedPSL <: Base.AbstractPipe
  input::Pipe; output::Pipe; process::Base.Process
  function RedPSL()
    # Setup pipes and reduce process
    input = Pipe(); output = Pipe()
    process = spawn(`redpsl`, (input, output, STDERR))
    # Close the unneeded ends of Pipes
    close(input.out); close(output.in)
    return new(input, output, process); end; end

Base.kill(rs::RedPSL) = kill(rs.process)
Base.process_exited(rs::RedPSL) = process_exited(rs.process)

const EOT = Char(4) # end of transmission character
function Base.write(rs::RedPSL, input::Compat.String)
  write(rs.input,"$input; symbolic write(string $(Int(EOT)));\n"); end

if VERSION < v"0.5.0"
  function Base.write(rs::RedPSL, input::UTF8String)
  write(rs.input, "$input; symbolic write(string $(Int(EOT)));\n"); end
  function Base.write(rs::RedPSL, input::ASCIIString)
  write(rs.input, "$input; symbolic write(string $(Int(EOT)));\n"); end
end

function ReduceCheck(output)
  contains(output,"***** ") && throw(ReduceError(split(output,'\n')[end-2])); end

const EOS = Char('$') # delimiter character
function Base.read(rs::RedPSL)
  output = readuntil(rs.output,EOT) |> String; readavailable(rs.output);
  ReduceCheck(output); output = split(output,EOS)[1] |> str -> rstrip(str,EOT)
  output = replace(output,r"[0-9]: ",EOS); return split(output,EOS)[end]; end

include("rexpr.jl")

## io

export string, show
import Base: string, show

string(r::RExpr) = r.str; show(io::IO, r::RExpr) = print(io, r.str)

@compat function show(io::IO, ::MIME"text/plain", r::RExpr)
  rcall(ra"on nat"); write(rs, r.str); output = readuntil(rs.output,EOT) |> String
  readavailable(rs.output); ReduceCheck(output); rcall(ra"off nat")
  output = join(split(output,"\n\n")[1:end-1],"\n\n")
  output = replace(output,r"[0-9]: ",EOS); print(io,split(output,EOS)[end]); end

@compat function show(io::IO, ::MIME"text/latex", r::RExpr)
  rcall(ra"on latex"); write(rs, r.str); output = read(rs)
  ReduceCheck(output); rcall(ra"off latex")
  print(io,"\$\$"*join(split(output,"\n")[2:end-3],"\n")*"\$\$"); end

## Setup

try
  if is_unix(); Reduce.@compat readstring(`which redpsl`)
  else; Reduce.@compat readstring(`which redpsl`); end
catch err
  error("Looks like Reduce is either not installed or not in the path"); end

# Server setup

const rs = RedPSL()         # Spin up a Reduce session
atexit(() -> kill(rs))      # Kill the session on exit

write(rs,"off nat")
banner = readuntil(rs.output,EOT) |> String; readavailable(rs.output);
ReduceCheck(banner); banner = split(banner,EOS)[1] |> str -> rstrip(str,EOS)
println(split(String(banner),'\n')[end-3])
ra"load_package rlfi" |> rcall

# REPL setup
#repl_active = isdefined(Base, :active_repl)  # Is an active repl defined?
#interactive = isinteractive()                # In interactive mode?

#if repl_active && interactive
#  repl_init(Base.active_repl)
#end

end # module
