@require "." start Response Request

@async start(8000) do req::Request{:GET}
  Response(200, ["Content-Type"=>"text/plain"])
end

@test `curl -sD - :8000` |> readall == """
                                       HTTP/1.1 200 OK\r
                                       Content-Type: text/plain\r
                                       \r
                                       """
