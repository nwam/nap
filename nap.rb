require 'rubygems'
require 'curb'

COOKIE = "cookie" #the name of the cookiefile



#http_action is an http GET or POST bound to a specific url
class Action

    def initialize(url, ref, post)
        @url = url
        @ref = ref
        @post = post
        @type = post.nil? ? "get" : "post"
        @res = ""
    end

    def perform
        post if @type == "post"
        get  if @type == "get"
    end

    #http POST which posts @post to @url reffered from @ref
    def post
        c = Curl::Easy.http_post(@url, @post) do |curl|
            #set options for post
            curl.url = @url
            curl.post_body = @post
            curl.headers["Referer"] = @ref
            curl.enable_cookies = true
            curl.cookiefile = COOKIE
            curl.cookiejar  = COOKIE
            curl.follow_location = true
        end

        @res = c.body_str
    end

    def get
        c = Curl::Easy.http_get(@url) do |curl|
            #set options for get
            curl.url = @url
            curl.headers["Referer"] = @ref
            curl.enable_cookies = true
            curl.cookiefile = COOKIE
            curl.cookiejar  = COOKIE
            curl.follow_location = true
        end

        @res = c.body_str
    end

    attr_reader :res
    private :post, :get

end






#events are an ordered group of http_actions
class Event
    @actions

    def initialize(freq, freq_rand)
        @frequency = freq
        @frequency_rand = freq_rand
    end
end



login = Action.new("http://www.neopets.com/login.phtml", nil, "username=username&password=password")
login.perform
puts login.res
