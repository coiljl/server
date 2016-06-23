@require "github.com/coiljl/status" messages
@require "github.com/coiljl/URI" URI

immutable HTTPServer <: Base.IOServer
  tcp::Base.TCPServer
  task::Task
end

Base.close(s::HTTPServer) = close(s.tcp)
Base.wait(s::HTTPServer) = wait(s.task)

"""
Listen for HTTP requests on `port`. Returns a HTTPServer which
should be `wait`ed on to hold the process open and ensure any
async errors are displayed

```julia
server = serve(3000) do req::Request{:GET}
  Response("Hello world")
end

println("server listening on http://localhost:3000")
wait(server)
```
"""
serve(fn::Any, port::Integer) = begin
  server = listen(port)
  task = @schedule while isopen(server)
    sock = accept(server)
    try
      request = Request(sock)
      write(sock, fn(request))
    catch e
      # ignore EPIPE errors since it just means the client no
      # longer cares about the response
      if !isa(e, Base.UVError) || e.code != -32
        isopen(sock) && write(sock, Response(500))
        rethrow(e)
      end
    end
    close(sock) # TODO: handle keep-alive
  end
  HTTPServer(server, task)
end

typealias Headers Dict{ASCIIString, ASCIIString}

immutable Request{method}
  uri::URI
  meta::Headers
  data::IO
end

Base.show(io::IO, r::Request) = begin
  print(io, typeof(r), '(', '"', r.uri, '"',  ',')
  showcompact(io, r.meta)
  print(io, ',')
  showcompact(io, r.data)
  print(io, ')')
end

"""
parse an incoming HTTP stream into a Request object

```julia
Request("GET /")
```
"""
Request(http::AbstractString) = Request(IOBuffer(http))
Request(io::IO) = begin
  head = readuntil(io, "\r\n")
  verb, path = split(rstrip(head), ' ')
  meta = Headers()
  for line in eachline(io)
    line = rstrip(line)
    isempty(line) && break
    key, value = split(line, ": ")
    meta[key] = value
  end
  Request{symbol(verb)}(URI(path), meta, io)
end

verb{method}(::Request{method}) = string(method)

immutable Response{T}
  status::Integer
  meta::Dict
  data::T
end

Base.show(io::IO, r::Response) = begin
  print(io, "Response(", Int(r.status), ",")
  showcompact(io, r.meta)
  print(io, ",")
  showcompact(io, r.data)
  print(io, ')')
end

Response(data::Any) = Response(200, data)
Response(s::Integer=200) = Response(s, Headers(), "")
Response(s::Integer, m::Dict) = Response(s, m, "")
Response(m::Dict, data::Any) = Response(200, m, data)
Response(s::Integer, data::Any) = Response(s, Headers(), data)
Response(typ::AbstractString, data::Any) = Response(MIME(typ), data)
Response(mime::MIME, data::Any) = begin
  body = applicable(writemime, STDOUT, mime, data) ? sprint(writemime, mime, data) : data
  Response(200, Dict("Content-Type"=>string(mime)), body)
end
Response{T}(s::Integer, m::Dict, d::T) = Response{T}(s, m, d)

const PROTOCOL = b"HTTP/1.1 "
const CLRF = b"\r\n"

"""
Render a Response as an outgoing HTTP message
"""
Base.write(io::IO, r::Response) = begin
  b = write(io, PROTOCOL, string(r.status), ' ', messages[r.status])
  for (key, value) in r.meta
    if key == "Set-Cookie"
      for cookie in vcat(value)
        b += write(io, CLRF, key, b": ", cookie[1], '=', cookie[2])
      end
    else
      b += write(io, CLRF, string(key), b": ", string(value))
    end
  end
  # add a Content-Length header if we can
  if !haskey(r.meta, "Content-Length") && isa(r.data, Union{AbstractString, Vector{UInt8}})
    b += write(io, CLRF, b"Content-Length: ", string(sizeof(r.data)))
  end
  b += write(io, CLRF, CLRF)
  b += write(io, r.data)
  return b
end
