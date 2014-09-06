@require "request" get
@require "."

@async start(8000) do req
  Response(200, ["Content-Type"=>"application/json"], "")
end

@test get(":8000").meta["Content-Type"] == "application/json"
