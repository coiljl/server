@require "Response" Response
@require "Request" Request
import Base.Socket

##
# Listen for HTTP requests on `port`. When one arrives it
# handles it asynchronously in a separate task. However it will
# immediately return to blocking while waiting for the next
# request making this an infinitely blocking function. So be
# aware that any code that comes after it will never run
#
function start(app::Function, port::Integer)
  server = listen(port)
  while true
    sock = accept(server)
    handle(sock, app)
  end
end

##
# Passes incoming HTTP Requests to `app` and writes the
# return value back to the client before closing the
# connection
#
function handle(sock::Socket, app::Function)
  req = Request(sock)
  res = try
    app(req)
  catch e
    Response(500, (e, catch_backtrace()))
  end
  write(sock, res)
  close(sock)
end
