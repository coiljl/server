import Base: TcpSocket, write, listen, writemime
@require "./status_codes" status_codes
@require "URI" URI

export start, Request, Response

typealias Headers Dict{String,String}

type Request
  verb::String  # valid HTTP method (e.g. "GET")
  uri::URI      # requested resource (e.g. uri"/hello/world")
  meta::Headers # HTTP headers
  data::Any     # request body
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
  Request(verb, URI(path), meta, stream)
end

type Response
  status::Int
  meta::Headers
  data::Any
end

Response{T<:String}(s::Int, m::Dict{T,T}) = Response(s, m, nothing)
Response(s::Int, d::Any) = Response(s, Headers(), d)
Response(s::Int) = Response(s, Headers())
Response() = Response(200)

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
    Response(500, (e, catch_backtrace()))
  end
  write(sock, res)
  close(sock)
end

##
# Render a Response as an outgoing HTTP message
#
function write(io::IO, r::Response)
  write(io, "HTTP/1.1 $(r.status) $(status_codes[r.status])")
  for (key,value) in r.meta
    write(io, "\r\n$key: $value")
  end
  write(io, "\r\n" ^ 2)

  if r.data === nothing
    nothing
  elseif isa(r.data, IO)
    while !eof(r.data) write(io, read(r.data, Uint8)) end
  else
    writemime(io, get(r.meta, "Content-Type", "text/plain"), r.data)
  end
end

##
# Render errors as they appear in a TTY
#
function writemime(io::IO, ::MIME"text/plain", e::(Exception,Array))
  Base.showerror(io, e[1])
  Base.show_backtrace(io, e[2])
end

writemime(io::IO, ::MIME"text/plain", s::String) = write(io, s)
writemime(io::IO, ::MIME"application/octet-stream", d) = write(io, d)
