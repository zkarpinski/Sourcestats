require 'socket'
require 'digest/md5'

class ProcessLogfiles

  def self.reset
  	ActiveRecord::Base.connection.execute("truncate players")    
  	ActiveRecord::Base.connection.execute("truncate bots")
  	ActiveRecord::Base.connection.execute("truncate player_events")    
  	ActiveRecord::Base.connection.execute("truncate active_players")    
  	ActiveRecord::Base.connection.execute("truncate server_events")    
  	ActiveRecord::Base.connection.execute("truncate team_events")    
  end

  def self.help
    puts "

*** process_logfiles.rb 
*** This script is part of Source Stats by Zach Karpinski
*** Source Stats can be downloaded at http://sourcestats.unrife.net/

This script can be invoked with the following command:
ruby script/runner -e development ProcessLogfiles.run server_ip:port remote_ip:port /path/to/srcds/logs/ sleep_interval

Arguments:

server ip:port
This is the IP and PORT that your source server can be connected to from the internet.  

remote ip:port
This is the IP address and PORT that the SourceStats Logger script is listening on.  This script makes a outgoing connection to this ip:port.
The port is 20808 by default.

/path/to/srcds/logs/
The directory that contains the logs you want to have processed.  Please tack on the trailing slash.

sleep_interval
Default is 0.05 seconds.  Since logaddress uses UDP the logging system does as well.  UDP is not a stateful connection and that means
data can be lost.  It is important to define something here so we do not try to send log data faster than the server can receive it.  
If you are processing data across a LAN or on the same server you can keep this very low.

"
  end
  
  def self.show_argv
    puts ARGV.inspect
  end
  def self.run
    path = ARGV[4]
    if not File.exists?("#{path}/processed")
      Dir::mkdir("#{path}/processed")
    end
    
    # UDP will cause data loss if we send information too fast, set a throttle interval
    if ARGV[5] 
      sleep_time = ARGV[5]
    else
      sleep_time = 0.05
    end
    
    # Get our IP:port to send along with the logs
    (host,port) = ARGV[3].split(":")
    
    # Create a UDP socket
    socket = UDPSocket.new
    socket.bind("",rand(10000).to_i + 40000)
    socket.connect(host,port)
    
    # Setup variables for our server's ip:port
    (server_ip,server_port) = ARGV[2].split(":")

    filenames = Dir.glob("#{path}/L*.log")      
    
    # Find the log files in the directory we were given
    for filename in filenames.sort

      # Create an MD5 checksum of this logfile, so we can process it only once
      digest = Digest::MD5.hexdigest(File.read(filename))

      # Send the lines in this file
      puts "Opening #{filename} (MD5 = #{digest})"
      log = File.new(filename, "r")
      while line = log.gets
        socket.send("sourcestats.log||#{digest}||#{ARGV[2]}||#{line}",0)
        if sleep_time != "false"
          sleep(sleep_time.to_f)
        end
      end
      log.close
    end
    socket.close
  end  
end
