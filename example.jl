@require "coiljl/server" start Response Request

handle(r::Request{:GET}) = Response("Hello World")
handle{verb}(r::Request{verb}) = Response("That was a $verb request")

server = start(handle, 8000)
server.closenotify |> wait
