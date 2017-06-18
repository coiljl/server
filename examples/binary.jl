handle(r::Request{:GET}) = Response("Hello World")
handle(r::Request{:PUT}) = throw(error("Boom"))
handle{verb}(r::Request{verb}) = Response("That was a $verb request")
