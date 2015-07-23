@require "coiljl/Response" Response
@require "coiljl/Request" Request

# Add iteration protocol
if !method_exists(Base.start, (Base.TcpServer,))
  Base.start(s::Base.TcpServer) = s
  Base.next(s::Base.TcpServer, _) = accept(s), s
  Base.done(s::Base.TcpServer, _) = !isopen(s)
end

##
# Listen for HTTP requests on `port`
#
function start(app::Function, port::Integer)
  server = listen(port)
  @schedule try
    for sock in server
      # TODO: handle premature client side closing
      write(sock, app(Request(sock))::Response)
      # TODO: handle keep-alive
      close(sock)
    end
  catch e
    # TODO: figure out how to notify with the error
    close(server)
  end
  server
end

test("start") do
  server = start(8000) do req::Request{:GET}
    Response(200, ["Content-Type"=>"text/plain"])
  end

  @test `curl -sD - :8000` |> readall == """
                                         HTTP/1.1 200 OK\r
                                         Content-Type: text/plain\r
                                         \r
                                         """
  close(server)
end
