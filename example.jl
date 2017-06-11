@require "." serve Response Request

struct InfiniteResponse end
Base.write(io::IO, r::InfiniteResponse) = begin
  write(io, Response(200))
  while true
    write(io, '-')
    sleep(0.1)
  end
end
handle(r::Request{:GET}) = Response("Hello World")
handle(r::Request{:PUT}) = throw(error("Boom"))
handle(r::Request{:POST}) = InfiniteResponse()
handle{verb}(r::Request{verb}) = Response("That was a $verb request")

server = serve(handle, 8000)

println("server listening on http://localhost:8000")
wait(server)
