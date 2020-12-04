module FHIR

  class Client

    attr_accessor :requests

    def record_requests(reply)
      @requests ||= []
      @requests << reply
    end

    def monitor_requests
      return if @decorated
      @decorated = true
      [:get, :put, :post, :delete, :head, :patch].each do |method|
        class_eval %Q{
          alias #{method}_original #{method}
          def #{method}(*args, &block)
            reply = #{method}_original(*args, &block)
            record_requests(reply)
            return reply
          end
        }
      end
    end

    def setup_security
      # TODO: implement oauth security?
      # options = self.get_oauth2_metadata_from_conformance
      # set_client_secrets(options) unless options.empty?
    end

    def set_client_secrets(options)
      puts "Using OAuth2 Options: #{options}"
      print 'Enter client id: '
      client_id = STDIN.gets.chomp
      print 'Enter client secret: '
      client_secret = STDIN.gets.chomp
      if client_id!="" && client_secret!=""
        options[:client_id] = client_id
        options[:client_secret] = client_secret
        # set_oauth2_auth(client,secret,authorizePath,tokenPath)
        self.set_oauth2_auth(options[:client_id],options[:client_secret],options[:authorize_url],options[:token_url])
      else
        puts "Ignoring OAuth2 credentials: empty id or secret. Using unsecured client..."
      end
    end

  end
end
