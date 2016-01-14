module LEDENET
  class Api
    API_PORT = 5577

    DEFAULT_OPTIONS = {
        reuse_connection: false,
        max_retries: 3
    }

    def initialize(device_address, options = {})
      @device_address = device_address
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def on
      send_bytes_action(0x71, 0x23, 0x0F, 0xA3)
      true
    end

    def off
      send_bytes_action(0x71, 0x24 ,0x0F, 0xA4)
      true
    end

    def on?
      # Bulbs respond with "35" or "36" (HEX: 23 or 24)
      # for on and off respectively
      power_state = status[2].unpack('C').to_s.delete('[]')
      if  power_state == "35"
        true
      else
        false
      end
    end

    def update_color(r,g,b) # Supports legacy color Updates
      update_ufo(r,g,b,0,false)
      true
    end

    def update_ufo(r,g,b,w,persist) # Update a UFO wireless device
      msg = Array.new
      if persist
        msg << 0x31
      else
        msg << 0x41 << r << g << b << w << 0x00 << 0x0f
      end
      checksum = calc_checksum(msg)
      send_bytes_action(*msg, checksum)
      true
    end

    def update_bulb_color(r, g, b, persist) # Update a Bulb wireless device's color
      msg = Array.new
      if persist
        msg << 0x31
      else
        msg << 0x41 << r << g << b << 0x00 << 0xf0 << 0x0f
      end
      checksum = calc_checksum(msg)
      send_bytes_action(*msg, checksum)
      true
    end

    def update_bulb_white(w, persist) # Update a Bulb wireless device's WW level
    msg = Array.new
    if persist
        msg << 0x31
      else
        msg << 0x41 << 0x00 << 0x00 << 0x00 << w << 0x0f << 0x0f
      end
        checksum = calc_checksum(msg)
        send_bytes_action(*msg, checksum)
        true
    end

    def current_status # Gets bytes 6-9 and returns them as Integers from 0-255 (Red,Green,Blue, and WW) and return power status as string
      current_packet = Array.new
      current_packet = status
      power_state = "off"
      power_state = "on" if current_packet[2].unpack('C').to_s.delete('[]') == "35"
      return Integer(current_packet[6].unpack('C').to_s.delete('[]')).to_i,Integer(current_packet[7].unpack('C').to_s.delete('[]')).to_i,Integer(current_packet[8].unpack('C').to_s.delete('[]')).to_i,Integer(current_packet[9].unpack('C').to_s.delete('[]')).to_i, power_state
    end

    def reconnect!
      create_socket
    end

    def getInfo
      msg = Array.new
      current_packet = Array.new
      current_packet = status
      msg << Integer(current_packet.each { |x| puts x }.unpack('C').to_s.delete('[]'))
    end

    private
      def calc_checksum(bytes)
        bytes.inject{|sum,x| sum + x } % 0x100
      end

      def status
        socket_action do
          msg = Array.new
          msg << 0x81 << 0x8A << 0x8B
          msg <<  calc_checksum(msg)
          send_bytes(*msg)
          flush_response(14)
        end
      end

      def flush_response(msg_length)
        @socket.recv(msg_length,Socket::MSG_WAITALL)
      end


      def send_bytes(*b)
        @socket.write(b.pack('c*'))
      end

      def send_bytes_action(*b)
        socket_action { send_bytes(*b) }
      end

      def create_socket
        @socket.close unless @socket.nil? or @socket.closed?
        @socket = TCPSocket.new(@device_address, API_PORT)
      end

      def socket_action
        tries = 0
        begin
          create_socket if @socket.nil? or @socket.closed?
          yield
        rescue Errno::EPIPE, IOError => e
          tries += 1

          if tries <= @options[:max_retries]
            reconnect!
            retry
          else
            raise e
          end
        ensure
          @socket.close unless @socket.closed? or @options[:reuse_connection]
        end
      end
  end
end
