import Base: TcpSocket, write, listen, writemime
@require "./status_codes" status_codes
@require "to-json"

export start, Request, Response

typealias Headers Dict{String,String}

type Request
  verb::String  # valid HTTP method (e.g. "GET")
  path::String  # requested resource (e.g. "/hello/world")
  meta::Headers # HTTP headers
  data::Any     # request body
  state::Dict   # used to store various data during request processing
end

##
# parse an incoming HTTP stream into a nice Request object
#
Request(stream::TcpSocket) = begin
  head = readuntil(stream, "\r\n" ^ 2)
  lines = split(head, "\r\n")
  verb, path = split(lines[1], ' ')
  meta = Headers()
  for line in lines[2:end-2]
    key, value = split(line, ": ")
    meta[key] = value
  end
  Request(verb, path, meta, stream, Dict())
end

type Response
  status::Int
  meta::Headers
  data::Any
end

Response(s::Int, d::Any) = Response(s, Headers(), d)
Response(s::Int) = Response(s, Headers(), "")
Response(d::Any) = Response(200, d)
Response() = Response(200)

##
# make Response objects pretty at the REPL
#
writemime(io::IO, ::MIME"text/plain", r::Response) =
  write(io,
        "Response($(r.status) $(status_codes[r.status]), ",
        "$(length(r.meta)) Headers, ",
        "$(sizeof(r.data)) Bytes in Body)")

##
# Listen for HTTP requests on `port`. When one arrives it
# handles it asynchronously in a separate task. However it will
# immediately return to blocking while waiting for the next
# request making this an infinitely blocking function. So be
# aware that any code that comes after it will never run
#
function start(app::Function, port::Integer)
  server = listen(port)
  while true
    sock = accept(server)
    handle(sock, app)
  end
end

##
# Passes incoming HTTP Requests to `app` and writes the
# return value back to the client before closing the
# connection
#
function handle(sock::TcpSocket, app::Function)
  req = Request(sock)
  res = try
    app(req)
  catch e
    Response(500, error_string(e, catch_backtrace()))
  end
  write(sock, res)
  close(sock)
end

##
# Render a Response as an outgoing HTTP message
#
function write(io::TcpSocket, r::Response)
  write(io, "HTTP/1.1 $(r.status) $(status_codes[r.status])")
  for (key,value) in r.meta
    write(io, "\r\n$key: $value")
  end
  write(io, "\r\n" ^ 2)
  writemime(io, get(r.meta, "Content-Type", "text/plain"), r.data)
end

function error_string(error::Exception, backtrace::Array)
  io = IOBuffer()
  Base.showerror(io, error)
  Base.show_backtrace(io, backtrace)
  takebuf_string(io)
end
