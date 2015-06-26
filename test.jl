@require "." start Response Request
@require "http" get

@async start(8000) do req::Request{:GET}
  Response(200, ["Content-Type"=>"text/plain"])
end

@async @test isa(@catch(wait(start(r -> :invalid, 8001))), TypeError)
@async get(":8001")

@test get(":8000").meta["Content-Type"] == "text/plain"
@test get(":8000").data == ""
