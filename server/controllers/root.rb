require_relative '../scaffold'

class RootController < Controller

    ROUTE ''

    GET '' do
        file("index.html")
    end

end
