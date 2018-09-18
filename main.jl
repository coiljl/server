@require "github.com/coiljl/status" messages
@require "github.com/coiljl/URI" URI
import Sockets: TCPServer, listen, accept, TCPSocket

struct HTTPServer <: Base.IOServer
  tcp::TCPServer
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
serve(fn::Any, port::Integer) = serve(fn, listen(port))
serve(fn::Any, server::TCPServer) = HTTPServer(server, @async handle_requests(fn, server))

handle_requests(fn::Any, server::TCPServer) = begin
  while isopen(server)
   sock = accept(server)
   keepalive = true
   while keepalive && request_received(sock)
     try
       request = Request(sock)
       keepalive = get(request.meta, "Connection", "keep-alive") == "keep-alive"
       write(sock, fn(request))
     catch e
       if !isEPIPE(e)
         isopen(sock) && write(sock, Response(500))
         rethrow(e)
       end
     end
   end
   close(sock)
 end
end

request_received(io::TCPSocket) = begin
  Base.wait_readnb(io, 1)
  isopen(io)
end

# EPIPE just means we tried to write to a closed stream
isEPIPE(e::Base.IOError) = e.code == -Libc.EPIPE
isEPIPE(e::Any) = false

"""
serve without the task wrapper so that stack traces can be preserved
"""
debug(fn::Any, port::Integer) = debug(fn, listen(port))
debug(fn::Any, server::TCPServer) = handle_requests(fn, server)

const Headers = Dict{String, String}

struct Request{method}
  uri::URI
  meta::Headers
  data::IO
end

Base.show(io::IO, r::Request) = begin
  print(io, typeof(r), '(', '"', r.uri, '"',  ',')
  repr(io, r.meta)
  print(io, ',')
  repr(io, r.data)
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
  parts = split(head, ' ')
  @assert length(parts) >= 2 "malformed HTTP head: $(repr(head))"
  verb, path = parts
  meta = Headers()
  for line in eachline(io)
    isempty(line) && break
    key, value = split(line, ": ")
    meta[key] = value
  end
  Request{Symbol(verb)}(URI(path), meta, io)
end

verb(::Request{method}) where method = String(method)

struct Response{T}
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
  body = applicable(stringmime, mime, data) ? stringmime(mime, data) : data
  Response(200, Dict("Content-Type"=>string(mime)), body)
end

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

  if suggested_encoding(r) == :chunked
    b += write(io, CLRF, b"Transfer-Encoding: chunked", CLRF, CLRF)
    while !eof(r.data)
      nb = bytesavailable(r.data)
      b += write(io, string(nb, base=16), CLRF, read(r.data, nb), CLRF)
    end
    return b + write(io, b"0", CLRF, CLRF)
  end

  bytes = buffer(r)
  b + write(io, CLRF, b"Content-Length: ", string(sizeof(bytes)), CLRF, CLRF, bytes)
end

suggested_encoding(::Response) = :identity
suggested_encoding(::Response{<:IO}) = :chunked

buffer(r::Response{<:Union{AbstractString,Vector{UInt8}}}) = r.data
buffer(r::Response) = sprint(write, r.data)
