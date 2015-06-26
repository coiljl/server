@require "Response" Response
@require "Request" Request

##
# Listen for HTTP requests on `port`. When one arrives it
# handles it asynchronously in a separate task. However it will
# immediately return to blocking while waiting for the next
# request making this an infinitely blocking function. So be
# aware that any code that comes after it will never run
#
function start(app::Function, port::Integer)
  server = listen(port)
  @schedule while true
    handle(accept(server), app)
  end
end

##
# Passes incoming HTTP Requests to `app` and writes the
# return value back to the client before closing the
# connection
#
function handle(sock::Base.Socket, app::Function)
  write(sock, app(Request(sock))::Response)
  close(sock)
end
