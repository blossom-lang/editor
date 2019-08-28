require 'socket'
require 'uri'
require 'net/http'
require 'net/https'
require 'openssl'
require 'json'
require 'date'

require_relative 'log'

Thread.abort_on_exception=true

class WebServer

    def initialize(port, handler)
        @port = port
        @handler = handler
        @logger = Logger.new("WebServer")
    end

    def stop
        @thread.kill
        @server.close
        @logger.log("Stopped.", Logger::INFO)
    end

    def begin(block=false)
        @server = TCPServer.new('localhost', @port)

        # sslContext = OpenSSL::SSL::SSLContext.new
        # sslContext.cert = OpenSSL::X509::Certificate.new(File.open("cert.pem"))
        # sslContext.key = OpenSSL::PKey::RSA.new(File.open("priv.pem"))
        # @sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)
        @logger.log("Listening on localhost:#{@port}", Logger::INFO)
        @thread = Thread.new { listen }
        @thread.join if block
    end

    def listen
        loop do
            # Thread.start(@sslServer.accept) do |connection|
            Thread.start(@server.accept) do |connection|
                handle_connection(connection)
            end
        end
    end

    def handle_connection(socket)
        @logger.log("Connected to socket: #{socket}", Logger::DEBUG)
        request = socket.gets
        handle_request(socket, request)
        socket.close
    end

    def handle_request(socket, request)
        return if request.nil?
        @logger.log("Received request: #{request}", Logger::DEBUG)
        request_method, *request_parts = request.split(" ")
        begin
            response_action = @handler.handle_request(socket, request_method.to_sym, request_parts)
        rescue StandardError => e
            @logger.log(e.to_s, Logger::ERROR)
            p e
            p e.backtrace
            @handler.server_error(socket, "An internal error occurred. You've done nothing wrong. Try again in a bit.")
        end
    end

end