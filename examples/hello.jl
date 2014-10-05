@require ".." start Response

start(8000) do req
  Response(200, [
    "Content-Type"=>"text/plain",
    "Content-Length"=>"11"
  ], "Hello world")
end
