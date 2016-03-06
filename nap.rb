require 'rubygems'
require 'curb'
require 'syslogger'

COOKIE  = "cookie"    # name of the cookiefile
LOGINFO = "loginfo"   # name of file with username and password

SECOND = 1
MINUTE = 60*SECOND
HOUR   = 60*MINUTE
DAY    = 24*HOUR



# --------Settings------------
# settings loads and holds all the info from external files
class Settings
  @username
  @password

  # loads settings
  def initialize
    $log.info "Loading settings"
    get_loginfo
  end

  # gets username and password from LOGINFO
  def get_loginfo
    File.open(LOGINFO, "r") do |loginfo_file|
      @username = loginfo_file.gets.chomp
      @password = loginfo_file.gets.chomp
    end
  end

  # getter methods
  attr_reader :username, :password
end



# -----------Action-------------
# http_action is an http GET or POST bound to a specific url
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
    $log.debug "POST #{@post} to #{@url}"
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
    $log.debug "GET #{@url}"
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



# ----------Event------------
# events are an ordered group of http_actions
class Event

  def initialize(actions, freq, freq_rand, message)
    @actions = actions          # array of Actions
    @freq = freq                # event frequency
    @freq_rand = freq_rand      # maximum random time to add to frequency
    @message = message          # message to print when performing event

    @last_performed = Time.at(0)  # last time the event was performed
    reset_wait
  end

  # perform all actions
  def perform
    $log.info "#{@message}"
    @actions.each do |action|
      action.perform
    end

    reset_wait
    @last_performed = Time.now
  end

  # resets the wait time, getting a new value in the frequency range
  def reset_wait
      @wait = @freq + rand(@freq_rand)
  end

  attr_reader :last_performed, :wait

end



# ----------EventWizard---------
# manages and runs all of the events
class EventWizard

  def initialize()
    @events = []
  end
      min_wait = 24*HOUR

  # main EventWizard function. 
  # Performs events when their wait times are exceeded
  def run
    $log.info "Starting Event Wizard"
    loop do
      # reset variables
      min_wait = 30*DAY

      # perform overdue events; get min_wait time
      @events.each do |event|
        event.perform if Time.now - event.last_performed >= event.wait
        min_wait = event.wait if event.wait < min_wait
      end

      # sleep until another event is ready
      $log.info "Sleeping for #{min_wait/MINUTE} minutes"
      sleep min_wait
    end
  end

  def add(event)
    @events << event
  end

end



# -------------MAIN-------------

# set up syslogger
$log = Syslogger.new("nap", Syslog::LOG_PERROR | Syslog::LOG_PID | Syslog::LOG_NDELAY, Syslog::LOG_USER)
$log.level = Logger::DEBUG

# create an Event Wizard
ew = EventWizard.new

# load Settings
settings = Settings.new
$log.info "Setting up Events"

# login/logout Actions
login  = Action.new("http://www.neopets.com/login.phtml", nil, "username=#{settings.username}&password=#{settings.password}")
logout = Action.new("http://www.neopets.com/logout.phtml", nil, nil)

# buy scratchcard Event
buy_sc0 = Action.new("http://www.neopets.com/winter/kiosk.phtml", nil, nil)
buy_sc1 = Action.new("http://www.neopets.com/winter/process_kiosk.phtml", "http://www.neopets.com/winter/kiosk.phtml", nil)
buy_sc  = Event.new( [login, buy_sc0, buy_sc1, logout], 6*HOUR, 2*HOUR, "Buying winter scratchcard")
ew.add(buy_sc)

# run the EventWizard
ew.run
