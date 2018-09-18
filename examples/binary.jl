handle(r::Request{:GET}) = Response("Hello World")
handle(r::Request{:PUT}) = throw(error("Boom"))
handle(r::Request{verb}) where verb = Response("That was a $verb request")
