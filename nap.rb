require 'rubygems'
require 'curb'
require 'syslogger'
require 'nokogiri'

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

  def initialize(url, ref, post, user = nil, pass = nil)
    @url = url
    @ref = ref
    @post = post
    @type = post.nil? ? "get" : "post"
    @res = ""
    @res_header = ""

    if user!=nil && pass!=nil then
        @type = "login"
        @@username = user
        @@password = pass
    end
  end

  # perform http request
  def perform
    post  if @type == "post"
    get   if @type == "get"
    login if @type == "login"
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
      curl.follow_location = true
    end

    @res = c.body_str
    @res_header = c.header_str
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
      curl.follow_location = true
    end

    @res = c.body_str
    @res_header = c.header_str
  end

  # login using a C program because Ruby is not fetching the right cookie
  def login
      $log.debug "Logging in" 
      `./nplogin #{@@username} #{@@password}`
  end

  # makes a request POST with no message
  def force_post
      @type = "post"
      @post = ""
  end

  # getter method for @res and make post and get private
  attr_reader :res, :res_header
  private :post, :get, :login

end

# ----------Fork-------------
class Fork
    
    def innitialize
        @actions
        @rules
        @input
    end
end


# ----------Event------------
# events are an ordered group of http_actions
class Event

  def initialize(actions, t, t_rand, message)
    @actions = actions          # array of Actions
    @t = t                      # event frequency
    @t_rand = t_rand            # maximum random time to add to frequency
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
      @wait = @t + rand(@t_rand)
  end

  attr_reader :last_performed, :wait

end

# ---------------DailyEvent-------------
# DailyEvents are performed once every day
# as opposed to once every t + t_rand
class DailyEvent < Event

    # overloaded to perform error checking
    def initialize(actions, t, t_rand, message)
        # check if t and t_rand are in range of one day
        if t + t_rand > DAY
            $log.error "Daily event time exceeds one day"
            exit 
        end
        #call super
        super(actions, t, t_rand, message)
    end

    def reset_wait
        now = Time.now
        tom = now + DAY
        @wait = Time.new(tom.year, tom.month, tom.day) + @t + rand(@t_rand) - now
    end
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

##### Create Actions and Events #####

# login/logout Actions
login  = Action.new("http://www.neopets.com/login.phtml", nil, nil, settings.username, settings.password)
logout = Action.new("http://www.neopets.com/logout.phtml", nil, nil)

### Irregularly timed events ###
# buy scratchcard **TESTED
sc0 = Action.new("http://www.neopets.com/winter/kiosk.phtml", nil, nil)
sc1 = Action.new("http://www.neopets.com/winter/process_kiosk.phtml", 
                     "http://www.neopets.com/winter/kiosk.phtml", nil)
sc  = Event.new( [login, sc0, sc1], 6*HOUR, 2*HOUR, "Buying winter scratchcard")
ew.add(sc)

# daily slots
ds0 = Action.new("http://www.neopets.com/dailyslots/slotgame.phtml", 
                 "http://www.neopets.com/index.phtml", nil)
ds1 = Action.new("http://www.neopets.com/dailyslots/ajax/claimprize.php", 
                 "http://www.neopets.com/index.phtml", nil)
ds  = Event.new( [login, ds0, ds1], 24*HOUR, 12*HOUR, "Spinning daily slots")
ew.add(ds)

# coltzan's shrine **TESTED
cs0 = Action.new("http://www.neopets.com/desert/shrine.phtml", nil, nil)
cs1 = Action.new("http://www.neopets.com/desert/shrine.phtml",
                 "http://www.neopets.com/desert/shrine.phtml", 
                 "type=approach")
cs = Event.new( [login, cs0, cs1], 12*HOUR, 4*HOUR, "Approaching the Shrine")
ew.add(cs)


### Daylies ###
# anchor management
am0 = Action.new("http://www.neopets.com/pirates/anchormanagement.phtml", 
                 "http://www.neopets.com/pirates/mansion.phtml", nil)
am1 = Action.new("http://www.neopets.com/pirates/anchormanagement.phtml", 
                 "http://www.neopets.com/pirates/anchormanagement.phtml", 
                 "action=ee7db8437176cc0e8c6563742228ba16")
am = Event.new( [am0, am1], 0, 0, "Managing an Anchor")

# tombola
tb0 = Action.new("http://www.neopets.com/island/tombola.phtml", nil, nil)
tb1 = Action.new("http://www.neopets.com/island/tombola2.phtml", 
                 "http://www.neopets.com/island/tombola.phtml", nil)
tb1.force_post
tb = Event.new( [tb0, tb1], 0, 0, "Playing Tombola")

# fruit machine
fm0 = Action.new("http://www.neopets.com/desert/fruitmachine.phtml", nil, nil)
fm1 = Action.new("http://www.neopets.com/desert/fruit/index.phtml", 
                 "http://www.neopets.com/desert/fruit/index.phtml",
                 "spin=1&ck=ee7db8437176cc0e8c6563742228ba16")
fm = Event.new( [fm0, fm1], 0, 0, "Spinning the Fruit Machine")

# all dailies
dailies = DailyEvent.new( [am, tb, fm], 12*HOUR, 8*HOUR, "Performing all dailies")
ew.add(dailies)

# run the EventWizard
# ew.run
login.perform
fm0.perform
test = fm1
test.perform

f = File.open("poo_header","w")
f.write(test.res_header)
f.close
f = File.open("poo.html", "w")
f.write(test.res)
f.close
