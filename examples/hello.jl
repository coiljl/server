@require "Request" Request verb
@require ".." start Response

handle(r::Request{:GET}) = Response("Hello World")
handle(r::Request) = Response("That was a $(verb(r)) request")

start(handle, 8000) |> wait
