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
serve(fn::Function, port::Integer) = begin
  server = listen(port)
  task = @schedule while isopen(server)
    sock = accept(server)
    write(sock, fn(Request(sock)))
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
parse an incoming HTTP stream into a nice Request object
"""
Request(io::IO) = begin
  head = readuntil(io, "\r\n")
  verb, path = split(head, ' ')
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

Response(s::Integer=200) = Response(s, Headers())
Response(data) = Response(200, data)
Response(s::Integer, m::Dict) = Response(s, m, nothing)
Response(s::Integer, data) = Response(s, Headers("Content-Length" => string(sizeof(data))), data)
Response{T}(s::Integer, m::Dict, d::T) = Response{T}(s, m, d)

const PROTOCOL = b"HTTP/1.1 "
const CLRF = b"\r\n"

"""
Render a Response as an outgoing HTTP message
"""
Base.write(io::IO, r::Response) = begin
  write(io, PROTOCOL, string(r.status), ' ', messages[r.status])
  for (key, value) in r.meta
    write(io, CLRF, string(key), b": ", string(value))
  end
  write(io, CLRF, CLRF)

  r.data ≡ nothing && return
  mime = MIME(get(r.meta, "Content-Type", "application/octet-stream"))
  if mimewritable(mime, r.data)
    writemime(io, mime, r.data)
  else
    write(io, r.data)
  end
end

# If not defined in core
try write(IOBuffer(), Base.TCPSocket()) catch
  Base.write(to::IO, from::IO) =
    while !eof(from)
      write(to, readavailable(from))
    end
end

##
# Render errors as they appear in a TTY
#
Base.writemime(io::IO, ::MIME"application/octet-stream", e::Tuple{Exception,Vector{Ptr{Void}}}) = begin
  Base.showerror(io, e[1])
  Base.show_backtrace(io, e[2])
end
