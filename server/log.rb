class Logger

    NONE    = 0
    FATAL   = 1
    ERROR   = 2
    WARNING = 3
    INFO    = 4
    DEBUG   = 5
    TRACE   = 6

    PRIORITY_STRINGS = %w(None Fatal Error Warning Info Debug Trace)

    attr_reader :last_message
    
    @@depths = {}

    def initialize(source, output=$stdout)
        @source = source
        @out = output
        @padding = 4
        @last_message = ""
        @importance_level = DEBUG
        @@depths[@out] ||= 0
    end

    def set_level(level)
        @importance_level = level
    end

    def push(message, importance=INFO)
        log(message, importance)
        @@depths[@out] += 1
    end

    def pop(message=nil, importance=INFO)
        @@depths[@out] -= 1
        @@depths[@out] = 0 if @@depths[@out] < 0
        log(message, importance) if !message.nil?
    end

    def trace(message)
        log(message, TRACE)
    end
    def debug(message)
        log(message, DEBUG)
    end
    def info(message)
        log(message, INFO)
    end
    def warn(message)
        log(message, WARNING)
    end
    def error(message)
        log(message, ERROR)
    end
    def fatal(message)
        log(message, FATAL)
    end

    def log(message, importance=INFO)
        log_message(message, importance)
    end

    def log_message(message, importance)
        return if importance > @importance_level
        @last_message = message
        @out.puts "[#{@source}] (#{PRIORITY_STRINGS[importance]}): " + (" " * @padding * @@depths[@out]) + message 
        @out.flush
    end

end