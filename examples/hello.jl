@require "Request" Request verb
@require ".." start Response

function handle(::Request{:GET})
  Response(200, [
    "Content-Type"=>"text/plain",
    "Content-Length"=>"11"
  ], "Hello World")
end

function handle(r::Request)
  msg = "That was a $(verb(r)) request"
  Response(200, [
    "Content-Type"=>"text/plain",
    "Content-Length"=>string(sizeof(msg))
  ], msg)
end

start(handle, 8000)
