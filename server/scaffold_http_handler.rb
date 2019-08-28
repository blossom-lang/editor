require_relative 'http_handler'
require_relative 'scaffold'

class ScaffoldingHttpHandler < HttpHandler

    def initialize(*args)
        super(*args)
        @logger.push("Loading Controllers", @logger.class::INFO)
        Dir["controllers/*.rb"].each do |file| 
            @logger.info("#{file}")
            load file 
        end
        @logger.pop()
    end

    def get_controller_type(route)
        valid_controllers = Controller.controllers.select { |c| c.match_path?(route) }
        return valid_controllers.first
    end

    # Overwritten
    def handle_request(socket, request_type, request_args)
        path = request_args[0][1..-1]
        @logger.trace(path)
        model = {} # TODO: get model somehow
        
        if path.match(/.\w+\z/)
            controller_type = nil
        else
            controller_type = get_controller_type(path)
        end

        if controller_type.nil?
            @logger.debug("No controller to handle the path. Serving file.")
            serve_file(socket, path)
        else
            path = path[controller_type.route_prefix.size..-1]
            path = path[1..-1] if path.start_with?("/")
            controller = controller_type.new(model)
            response = controller.handle_request(request_type, path)
            case response
            when ActionResult::View
                raise NotImplementedError
            when ActionResult::HttpStatus
                @logger.trace("Serving HTTP status.")
                return http_status(socket, response.status_code, response.status_name, response.message)
            when ActionResult::Content
                @logger.trace("Serving content.")
                return serve_content(socket, response.type, response.body)
            when ActionResult::FileText
                @logger.trace("Serving a text file.")
                return serve_file(socket, response.filepath, response.variables)
            when ActionResult::FileStream
                raise NotImplementedError
            when ActionResult::FileBinary
                raise NotImplementedError
            end
                
            p response
        end
    end

end
