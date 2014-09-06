
# server

A simple base for building HTTP servers with Julia

## Installation

With [packin](//github.com/jkroso/packin): `packin add jkroso/server`

## API

### start(app::Function, port::Int)

Starts listening for connections to `localhost:$port`. When one is made it will interpret it as an incoming HTTP message. This message is reified as a `Request` object and passed to `app`. The value `app(req::Request)` returns is then written back to the client as an HTTP response using `Base.write`.

### Response

The function you pass to `start` should return a `Response` object since `Base.write` already knows how to serialize it as an HTTP message

```julia
type Response
  status::Int
  meta::Headers
  data::Any
end
```

### Request

This is the type of object passed into your app. It is defined as follows:

```julia
type Request
  verb::String  # valid HTTP method (e.g. "GET")
  path::String  # requested resource (e.g. "/hello/world")
  meta::Headers # HTTP headers
  data::Any     # request body
  state::Dict   # used to store various data during request processing
end
```
