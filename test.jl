@require "request" get
@require "."

@async start(8000) do req
  Response(200, ["Content-Type"=>"text/plain"], "")
end

@test get(":8000").meta["Content-Type"] == "text/plain"

type NonWriteable end
@test_throws Exception @sync begin
  @async start(8001) do req NonWriteable() end
  @async get(":8001")
end
