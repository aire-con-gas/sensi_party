require 'open-uri'
require 'json'
require 'rest-client'

class SensiParty::Sensi
  SUCCESS_CODE = 200

  def initialize
    @username = ''
    @password = ''
    @baseUrl = 'https://bus-serv.sensicomfort.com'
    @defaultHeaders = {
      'X-Requested-With' => 'XMLHttpRequest',
      'Accept'=> 'application/json; version=1, */*; q=0.01'
    }
    @cookies = nil
    @connectionToken = nil
    @thermostats = nil
    @incrementor = 0
  end

  def start
    self.authorize do
      self.negotiate
    end
  end

  def authorize
    response = nil
    url =  "#{@baseUrl}/api/authorize"
    data = {
      'UserName': @username,
      'Password': @password
    }
    additionalOpts = {
      headers: @defaultHeaders,
      payload: URI.encode_www_form(data)
    }

    response = self.sendRequest(url, :post, additionalOpts)
    @cookies = response.cookies unless response.code != SUCCESS_CODE
    yield if response.code == SUCCESS_CODE && block_given?
  end

  def negotiate
    response = nil
    url = "#{@baseUrl}/realtime/negotiate"

    response = self.sendRequest(url, :get)
    json = JSON.parse(response)
    @connectionToken = json['ConnectionToken']
  end

  def getThermostats
    response = nil
    url = "#{@baseUrl}/api/thermostats"

    additionalOpts = {
      headers: @defaultHeaders.merge({'Accept-Encoding': 'gzip, deflate, sdch'}),
      cookies: @cookies
    }

    response = self.sendRequest(url, :get, additionalOpts)
    json = JSON.parse(response)
    @thermostats = json
  end

  def turnOff
    buildSendRequest(:Off)
  end

  def setHeat(temperature)
    buildSendRequest(:Heat)
    buildSendRequest(:SetHeat, temperature)
  end

  protected

  def getConnectionToken
    @connectionToken ||= self.negotiate()
  end

  def getFirstThermostat
    self.getThermostats if @thermostats.nil?
    @thermostats.first
  end

  def buildSendRequest(cmd, *args)
    response = nil
    url = "#{@baseUrl}/realtime/send"

    payloadRequest = buildPayloadRequest(cmd, args)
    @incrementor += 1

    additionalOpts = {
      headers: @defaultHeaders.merge({
        'Accept-Encoding': 'gzip, deflate',
      }),
      params: {
        transport: 'longPolling',
        connectionToken: self.getConnectionToken()
      },
      cookies: @cookies,
      payload: URI.encode({
        "H": "thermostat-v1",
        "M": payloadRequest[:M],
        "A": payloadRequest[:A],
        "I": @incrementor.to_s
        }.to_s),
      timeout: nil
    }

    response = self.sendRequest(url, :post, additionalOpts)
  end

  def buildPayloadRequest(cmd, *args)
    result = {:A => []}
    commandsLookup = {
      :Off => ['SetSystemMode', 'Off'],
      :Heat => ['SetSystemMode', 'Heat'],
      :SetHeat => ['SetHeat', '**X**', 'F']
    }

    command = commandsLookup[cmd]
    result[:M] = command.shift.to_s
    icd = self.getFirstThermostat()['ICD']
    
    result[:A] = command.unshift(icd).inject([]){|acc, item|
      if item =~ /\*\*X\*\*/
        acc << args.shift
      else
        acc << item.to_s
      end

      acc
    }
    
    result
  end

  def sendRequest(url, method, opts={})
    response = nil
    defaultArgs = {
      url: url,
      method: method
    }

    begin
      response = ::RestClient::Request.execute(defaultArgs.merge(opts))
    rescue ::RestClient::ExceptionWithResponse => err
      puts "RestClient::ExceptionWtihResponse #{err}"
    rescue Exception => err
      puts err
    end

    return response
  end

end
