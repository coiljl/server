import Base: write, serialize
import JSON.parse
Require.require("to-json")
@require ".."

##
# Compose a sequence of transducers (for lack of a better word)
# to create a middleware function
#
# Middlwares should have the signature (req, res) -> res|x
# While transducers have the signature (middlewareA) -> middlewareB
#
compose(stack::Function...) = begin
  foldr((_,res) -> res, stack) do transducer, next_middleware
    transducer(next_middleware)
  end
end

##
# Makes a Response object available to all downstream middleware
# so they can incrementally extend it
#
function response_handler(next)
  function middleware(req)
    res = Response()
    next(req, res)
    res
  end
end

##
# Log request handling info
#
# NB: This is why this format of middleware is more powerful than
# the style meddle uses. This style allows you do do things both
# before and after downstream middleware while meddle middleware
# can only do things before
#
function logger(next)
  function middleware(req, res)
    time = @elapsed ret = next(req, res)
    time = int(time * 1000)
    println("$(res.status) $(req.path) $(time)ms")
    ret
  end
end

const parsers = [
  "application/json" => (req) -> parse(buffer(req))
]

buffer(req::Request) = begin
  if req.verb != "POST" return "" end
  len = int(req.meta["Content-Length"])
  out = ""
  while length(out) < len && isopen(req.data)
    out *= readavailable(req.data)
  end
  out
end

##
# Hydrate the requests body
#
function body_parser(next)
  function middleware(req, res)
    typ = get(req.meta, "Content-Type", "")
    typ = split(typ, "; ")[1]
    parse = get(parsers, typ, buffer)
    req.data = parse(req)
    next(req, res)
  end
end

##
# Copy data from the request to the response
#
function echo(next)
  function middleware(req, res)
    res.data = req.data
    res.meta["Content-Type"] = get(req.meta, "Accept", "text/plain")
    next(req, res)
  end
end

start(compose(response_handler, logger, body_parser, echo), 8000)
