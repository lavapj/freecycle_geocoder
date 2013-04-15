#### freecycle mail app


$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'mail_config'
require 'mail'
require 'json'

# http://blog.rubybestpractices.com/posts/gregory/033-issue-4-configurable.html
# http://metabates.com/2011/06/28/lets-say-goodbye-to-yaml-for-configuration-shall-we/


# 'lib/mail_config.rb should be a ruby file in the following format:

# module FreeCycleConfig
#   USER_CONFIG = {
#     :user_name => "username",
#     :password => "password" }
#   MAIL_CONFIG = {
#     :server => "mailserver",
#     :group => "freecycle mailing list email address" }
#   LOCATION_SPECIFIER = "What to add to location for searches"
# end

# !!! FIXME [wc 2013-03-13]: This is somewhat bad

module FreeCycleMail

  LOCATION_SPECIFIER = FreeCycleConfig::LOCATION_SPECIFIER
  
  CREDENTIALS = {
    :port => 993,
    :enable_ssl => true
  }

  CREDENTIALS[:address] = FreeCycleConfig::MAIL_CONFIG[:server]
  CREDENTIALS[:user_name] = FreeCycleConfig::USER_CONFIG[:user_name]
  CREDENTIALS[:password] = FreeCycleConfig::USER_CONFIG[:password]

  Mail.defaults { retriever_method :imap, CREDENTIALS }

# Now we are ready to retrieve mail and work with them.

  def FreeCycleMail.search_for_location (subject)
    # Search a subject for possible locations
    
    # first check for location in parentheses
    location = subject.scan(/\(.*\)/).first
    unless location.nil?
      if location.is_a? String
        location = location[1..-2]
      end
    end

    # check for location after one or more dashes
    if location.nil?
      s = subject.split(/-+/).last
      s == subject ? location = nil : location = s.strip
    end
    
    # check for location after the last word "in"
    if location.nil?
      s = subject.split(/in /).last
      s == subject ? location = nil : location = s.strip
    end
    
    # raise an error if somehow the location in string is neither nil or
    # string
    unless location.nil?
      unless location.is_a? String
        raise "Location, #{location}, neither nil or String."
      end

      #FIXME: the location specifier is really most useful for the
      #geocoding and this may not be the best place to put it.
      unless LOCATION_SPECIFIER
        location += ", #{LOCATION_SPECIFIER}"
      end
    end
    return location
  end

  # http://rubydoc.info/gems/mail

  def FreeCycleMail.make_email_data(email)
    data = {}
    data[:date] = email.date
    data[:message_id] = email.message_id
    data[:subject] = email.subject
    data[:location] = search_for_location(email.subject)
    data[:body] = email.body
    return data
  end

  def FreeCycleMail.get_recent_offers(count=nil)
    offers = Mail.find({
                         :order => :desc,
                         :what => :last,
                         :count => count,
                         :keys => ["SUBJECT", "OFFER"]
                       })
    if offers.is_a? Mail::Message
      return [offers]
    elsif offers.is_a? Array
      return offers
    else
      raise "Invalid return from Mail.find."
    end
  end
  
  def FreeCycleMail.recent_offers (count=nil)
    # Returns a list of subject lines with the word 'offer' in them.
      get_recent_offers.map { |email| make_email_data(email) }
  end
  
  def FreeCycleMail.recent_offers_web_data
    # Return a json string of recent offer data
    return recent_offers().to_json
  end
  
end
