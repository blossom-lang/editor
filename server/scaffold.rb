class ActionResult

    class View < ActionResult
    end

    class HttpStatus < ActionResult
        attr_reader :status_code
        attr_reader :status_name
        attr_reader :message
        def initialize(status_code, status_name, message)
            @status_code = status_code
            @status_name = status_name
            @message = message
        end
    end

    class Content < ActionResult
        attr_reader :type
        attr_reader :encoding
        attr_reader :body
        def initialize(type, encoding, body)
            @type = type
            @encoding = encoding
            @body = body
        end
    end

    class FileText < ActionResult
        attr_reader :filepath
        attr_reader :variables
        def initialize(filepath, variables=nil)
            @filepath = filepath
            @variables = variables
        end
    end

    class FileStream < ActionResult
    end

    class FileBinary < ActionResult
    end

end



class Action

    METHODS = [:GET, :POST, ] # @TODO: Add others

    attr_reader :param_names

    def initialize(http_method, controller, path, parameters, block_body)
        @http_method  = http_method
        @controller   = controller
        @path         = path
        @path_pattern = Regexp.new path.gsub(/\{(\w+?)\}/) { "(?<#{$1}>.+)" }
        @arity        = parameters.size
        @param_names  = parameters.map { |p| p[1].to_s }
        @handler      = block_body
    end

    def call(*args)
        @controller.instance_exec(@handler, *args) do |block, *args|
            @result = block.call(*args)
        end
        return @controller.instance_eval do
            @result
        end
    end

    def match_method?(http_method)
        return @http_method == http_method
    end

    def match_path?(path)
        return true if path.nil?
        return false if @path_pattern == // and path != ""
        return path.match(@path_pattern)
    end

    def match_args?(args)
        return args.size == @arity
        # @TODO: check ranges of argument-counts (for optional args)
    end

end

class Controller

    class << self
        attr_accessor :actions
        attr_accessor :route_prefix
        attr_accessor :model
    end
  
    @actions      = []
    @route_prefix = ""
    @model        = nil

    @@controllers = []

    def self.controllers
        return @@controllers
    end

    def self.match_path?(path)
        return path.start_with?(self.route_prefix)
    end

    MULTIPLE_ACTION_SOULTION = :LAST # Options are :FIRST, :LAST, :ERROR

    def initialize(model)
        @logger = Logger.new(self.class.name)
        self.class.model  = model
    end

    def handle_request(request_type, location)
        possible_actions = self.class.actions.select { |a| a.match_method?(request_type) }
        args = {}
        possible_actions = possible_actions.select { |a| args[a] = a.match_path?(location) }
        possible_actions = possible_actions.select { |a| a.match_args?(args[a].named_captures) }
        if possible_actions.empty?
            path = self.class.route_prefix + "/" + location
            @logger.debug("Returned a 404 for #{path}.")
            return Controller.http_status(404, "Not Found", "404. No response to request for #{path}.")
        elsif possible_actions.size == 1
            perform_action(possible_actions.first, args[possible_actions.first])
        else
            case MULTIPLE_ACTION_SOULTION
            when :FIRST
                warning_message = "There were multiple possible actions for #{location}. " +
                "Defaulting to the first.\nTo change this behaviour, see Controller::MULTIPLE_ACTION_SOULTION."
                @logger.warn(warning_message)
                perform_action(possible_actions.first, args[possible_actions.first])
            when :LAST
                warning_message = "There were multiple possible actions for #{location}. " +
                "Defaulting to the last.\nTo change this behaviour, see Controller::MULTIPLE_ACTION_SOULTION."
                @logger.warn(warning_message)
                perform_action(possible_actions.last, args[possible_actions.last])
            else
                error_message = "There were multiple possible actions for #{location}. " +
                "To change this behaviour to just emit warnings, see Controller::MULTIPLE_ACTION_SOULTION."
                @logger.error(error_message)
                return Controller.http_status(500, "Internal Server Error", "")
            end
        end
    end

    def perform_action(action, arg_match)
        args = []
        arg_match.named_captures.each { |name, value| args[action.param_names.index(name)] = value }
        return action.call(*args)
    end

    def self.redirect(location, *args)
        handle_request(location, *args)
    end
    
    def self.view(path, *args)
        raise NotImplementedError
        # return ActionResult::View.new
    end

    def self.file(filename, variables=nil)
        return ActionResult::FileText.new(filename, variables)
    end

    def self.raw(type, encoding, body)
        return ActionResult::Content.new(type, encoding, body)
    end

    def self.http_status(status_code, status_name, message="")
        return ActionResult::HttpStatus.new(status_code, status_name, message)
    end

    def self.ROUTE(path)
        @@controllers.push(self) if !@@controllers.include?(self)
        self.route_prefix = path
    end

    def self.GET(path, &block)
        @@controllers.push(self) if !@@controllers.include?(self)
        self.actions ||= []
        self.actions.push(Action.new(:GET, self, path, block.parameters, block))
    end

    def self.POST(path, &block)
        @@controllers.push(self) if !@@controllers.include?(self)
        self.actions ||= []
        self.actions.push(Action.new(:POST, self, path, block.parameters, block))
    end

end