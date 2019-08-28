require_relative 'web_server'

class HttpHandler

    EMPTY_LINE =  "\r\n"
    EXTENSIONS = ['.html']

    @@web_root = './public'

    def self.file_contents(filepath)
        filename = get_file_path(filepath)
        if File.exists?(filename)
            return File.read(filename)
        end
        return nil
    end

    def self.get_file_path(filepath)
        filename = File.join(@@web_root, *clean_file_path(filepath))
        if File.directory?(filename)
            EXTENSIONS.each do |extension|
                index_name = File.join(filename, 'index' + extension)
                if File.exists?(index_name)
                    return index_name
                end
            end
        end
        return filename
    end

    def self.clean_file_path(filepath)
        if filepath.is_a?(String)
            filepath = filepath.split("/")
        end
        clean = []
        filepath.each do |part|
            next if part.empty? || part == '.'
            case part
            when '..'
                clean.pop
            when '~'
                clean.push(@@web_root)
            else
                clean.push(part)
            end
        end
        return clean
    end

    def initialize(web_root=nil)
        @logger = Logger.new("HTTP Handler")
        @@web_root = web_root if !web_root.nil?
    end

    # To be overridden to handle requests by subclasses.
    def handle_request(socket, request_type, request_args)
        raise 'not implemented'
    end

    def get_file_type(filename)
        # Text Filetypes
        if filename.end_with? ".css"
            return "text/css"
        end
        if filename.end_with? ".html"
            return "text/html"
        end

        # Image Filetypes
        if filename.end_with? ".jpg" or filename.end_with? ".jpeg"
            return "image/jpeg"
        end
        if filename.end_with? ".png" 
            return "image/png"
        end
        if filename.end_with? ".gif"
            return "image/gif"
        end

        return "text/plain"
    end

    # To be overridden to handle preprocessing.
    def parse_file_contents(filename, file_contents, args)
        return file_contents
    end

    def get_file_contents(socket, filepath, variables=nil)
        filename = HttpHandler.get_file_path(filepath)
        file_string = HttpHandler.file_contents(filepath)

        if file_string.nil?
            return
        end

        content_type = get_file_type(filename)

        file_string = parse_file_contents(filename, file_string, variables)

        file_string += EMPTY_LINE
        return file_string, content_type
    end

    # Helper functions for returning standard HTTP responses.

    def serve_file(socket, filepath, variables=nil)
        file_string, content_type = get_file_contents(socket, filepath, variables)

        if file_string.nil?
            file_not_found(socket, filepath + " not found.")
            return
        end

        serve_content(socket, content_type, file_string)
    end

    def no_content(socket)
        socket.print http_header(204, "No Content")
        socket.print EMPTY_LINE
    end

    def file_not_found(socket, message="File not found")
        @logger.log(message, Logger::DEBUG)
        message += EMPTY_LINE

        error_content_type = "text/plain"
        message_size = message.size
        EXTENSIONS.each do |extension|
            error_404, content_type = get_file_contents(socket, "404" + extension)
            if !error_404.nil?
                message = error_404
                error_content_type = content_type
                message_size = message.bytesize
                break
            end
        end
        
        socket.print http_header(404, "Not Found", {"Content-Type"=>error_content_type, "Content-Length"=>message_size})
        socket.print EMPTY_LINE
        socket.print message
    end

    def bad_request(socket, message="Bad Request")
        @logger.log(message, Logger::DEBUG)
        message += EMPTY_LINE
        socket.print http_header(400, "Bad Request", {"Content-Type"=>"text/plain", "Content-Length"=>message.size})
        socket.print EMPTY_LINE
        socket.print message
    end

    def server_error(socket, message="Internal Server Error")
        @logger.log(message, Logger::ERROR)
        message += EMPTY_LINE
        socket.print http_header(500, "Internal Server Error", {"Content-Type"=>"text/plain", "Content-Length"=>message.size})
        socket.print EMPTY_LINE
        socket.print message
    end

    def serve_content(socket, content_type, body)
        socket.print http_header(200, "OK", {"Content-Type"=>content_type, "Content-Length"=>body.bytesize})
        socket.print EMPTY_LINE
        socket.print body
    end

    def http_status(socket, status_code, status_name, message)
        socket.print http_header(status_code, status_name, {"Content-Type"=>"text/plain", "Content-Length"=>message.bytesize})
        socket.print EMPTY_LINE
        socket.print message
    end

    def http_header(status_code, status_message, headers={})
        response =  "HTTP/1.1 #{status_code} #{status_message}\r\n"
        headers.each do |key, value|
            response += "#{key}: #{value}\r\n"
        end
        response += "Connection: close\r\n"
        response
    end

end