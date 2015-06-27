@require "Response" Response
@require "Request" Request

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
  for sock in listen(port)
    write(sock, app(Request(sock))::Response)
    close(sock)
  end
end
