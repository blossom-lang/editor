require_relative '../scaffold'

class GraphController < Controller

    ROUTE 'graph'

    GET 'load/{filename}' do |filename|
        file("#{filename}.blsm")
    end

    GET 'new' do
        raw("text/x-blossom", "utf-8", "[]")
    end

    POST 'status' do
        http_status(200, "Okay")
    end

end
