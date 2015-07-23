@require "coiljl/Request" Request verb
@require "coiljl/server" start Response

handle(r::Request{:GET}) = Response("Hello World")
handle(r::Request) = Response("That was a $(verb(r)) request")

start(handle, 8000)
