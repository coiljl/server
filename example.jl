@require "." serve Response Request

handle(r::Request{:GET}) = Response("Hello World")
handle(r::Request{:PUT}) = throw(error("Boom"))
handle{verb}(r::Request{verb}) = Response("That was a $verb request")

server = serve(handle, 8000)

println("server listening on http://localhost:3000")
wait(server)
