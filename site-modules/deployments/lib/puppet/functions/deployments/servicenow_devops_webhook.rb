require 'net/http'
require 'uri'
require 'json'

Puppet::Functions.create_function(:'deployments::servicenow_devops_webhook') do
  dispatch :servicenow_devops_webhook do
    required_param 'String', :endpoint
    required_param 'Hash', :payload
  end

  def servicenow_devops_webhook(endpoint, payload = '')
    uri = URI.parse(endpoint)

    connection = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      connection.use_ssl = true
    end

    connection.read_timeout = 15

    headers = { 'Content-Type': 'application/json' }

    max_attempts = 3
    attempts = 0

    while attempts < max_attempts
      attempts += 1
      begin
        Puppet.debug("servicenow_devops_webhook: posting to #{endpoint}")
        response = connection.post(uri.path, payload.to_json, headers)
      rescue SocketError => e
        raise Puppet::Error, "Could not connect to the ServiceNow DevOps endpoint at #{uri.host}: #{e.inspect}", e.backtrace
      end

      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        return response
      when Net::HTTPInternalServerError
        if attempts < max_attempts # rubocop:disable Style/GuardClause
          Puppet.debug("Received #{response} error from #{uri.host}, attempting to retry. (Attempt #{attempts} of #{max_attempts})")
          Kernel.sleep(3)
        else
          raise Puppet::Error, "Received #{attempts} server error responses from the ServiceNow DevOps endpoint at #{uri.host}: #{response.code} #{response.body}"
        end
      else
        return response
      end
    end
  end
end
