require 'rubygems'
require 'curb'

COOKIE  = "cookie"      # name of the cookiefile
LOGINFO = "loginfo"     # name of file with username and password


#http_action is an http GET or POST bound to a specific url
class Action

    def initialize(url, ref, post)
        @url = url
        @ref = ref
        @post = post
        @type = post.nil? ? "get" : "post"
        @res = ""
    end

    # perform http request
    def perform
        post if @type == "post"
        get  if @type == "get"
    end

    # http POST which posts @post to @url reffered from @ref
    # @res holds http response
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

    # http GET which gets @url reffered from @ref
    # @res holds http response
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

    # getter method for @res and make post and get private
    attr_reader :res
    private :post, :get

end



# events are an ordered group of http_actions
class Event
    @actions

    def initialize(freq, freq_rand)
        @frequency = freq
        @frequency_rand = freq_rand
    end
end



# settings loads and holds all the info from external files
class Settings
    @username
    @password

    # loads settings
    def initialize
        get_loginfo
    end

    # gets username and password from LOGINFO
    def get_loginfo
        File.open(LOGINFO, "r") do |loginfo_file|
            @username = loginfo_file.gets
            @password = loginfo_file.gets
        end
    end

    # getter methods
    attr_reader :username, :password


end

settings = Settings.new
login = Action.new("http://www.neopets.com/login.phtml", nil, "username=#{settings.username}&password=#{settings.password}")
login.perform
