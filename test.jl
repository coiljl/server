@require "request" get
@require "."

@async start(8000) do req
  Response(200, ["Content-Type"=>"application/json"], "")
end

@test get(":8000").meta["Content-Type"] == "application/json"

type NonWriteable end
@test_throws @sync begin
  @async start(8001) do req NonWriteable() end
  @async get(":8001")
end
