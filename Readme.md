
# server

A simple base for building HTTP servers with Julia

## Installation

With [packin](//github.com/jkroso/packin): `packin add coiljl/server`

## API

```julia
@require "server" start
```

### start(app::Function, port::Int)

Starts listening for connections to `localhost:$port`. When one is made it will interpret it as an incoming HTTP message. This message is reified as a `Request` object and passed to `app`. The value `app(req::Request)` returns is then written back to the client as an HTTP response using `Base.write`. The hello world server looks like this:

```julia
start(8000) do req::Request
  Response(200, "Hello world")
end
```
