@require ".." serve Response Request

mutable struct RepeatStream <: IO
  remaining::Int
end
Base.bytesavailable(s::RepeatStream) = s.remaining > 0 ? 1 : 0
Base.read(s::RepeatStream, nb::Integer) = begin
  s.remaining -= nb
  Vector{UInt8}(repeat("-", nb))
end
Base.eof(s::RepeatStream) = s.remaining <= 0
Base.readavailable(s::RepeatStream) = read(s, bytesavailable(s))

handle(r::Request{:GET}) = Response("Hello World")
handle(r::Request{:PUT}) = throw(error("Boom"))
handle(r::Request{:POST}) = Response(200, RepeatStream(rand(UInt8)))
handle(r::Request{verb}) where verb = Response("That was a $verb request")

server = serve(handle, 8000)

println("server listening on http://localhost:8000")
wait(server)
