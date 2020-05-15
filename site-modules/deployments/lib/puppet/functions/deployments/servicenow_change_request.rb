require 'net/http'
require 'uri'
require 'json'

Puppet::Functions.create_function(:'deployments::servicenow_change_request') do
  dispatch :servicenow_change_request do
    required_param 'String', :endpoint
    required_param 'String', :username
    required_param 'String', :password
    required_param 'Hash', :report
    required_param 'Integer', :promote_to_stage
  end

  def servicenow_change_request(endpoint, username, password, report, promote_to_stage)
    # changereq = {}
    # changereq['commitSHA']       = report['scm']['commit']
    # changereq['deploymentId']    = report['build']['number']
    # changereq['pipelineId']      = report['build']['pipeline']
    # changereq['workspace']       = report['build']['owner']
    # changereq['repoName']        = report['build']['repo_name']
    # changereq['repoType']        = report['build']['repo_type']
    # changereq['promoteToStage']  = promote_to_stage
    # changereq['scm_branch']      = report['scm']['branch']
    # bln_ia_safe_verdict = true
    # report['notes'].each do |ia|
    #   unless ia['IA_verdict'] == 'safe'
    #     bln_ia_safe_verdict = false
    #   end
    # end
    # changereq['impact_analysis'] = bln_ia_safe_verdict ? 'safe' : 'unsafe'

    # First, we need to create a new ServiceNow Change Request
    api_path = '/api/sn_chg_rest/v1/change/normal'
    description = "Puppet CD4PE Automated Change Request for promoting commit #{report['scm']['commit']} to stage #{promote_to_stage}"
    short_description = "Puppet CD4PE - promote #{report['scm']['commit'][0,7]} to stage #{promote_to_stage}"
    request_uri = "#{endpoint}#{api_path}?description=#{description}&short_description=#{short_description}"
    make_request(request_uri, :post, username, password)
  end

  def make_request(endpoint, type, username, password, payload = nil)
    uri = URI.parse(endpoint)

    connection = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      connection.use_ssl = true
    end

    connection.read_timeout = 60

    max_attempts = 3
    attempts = 0

    while attempts < max_attempts
      attempts += 1
      begin
        Puppet.debug("servicenow_change_request: performing #{type} request to #{endpoint}")
        case type
        when :delete
          request = Net::HTTP::Delete.new(uri.request_uri)
        when :get
          request = Net::HTTP::Get.new(uri.request_uri)
        when :post
          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data = payload.to_json unless payload.nil?
        when :patch
          request = Net::HTTP::Patch.new(uri.request_uri)
          request.set_form_data = payload.to_json unless payload.nil?
        else
          raise Puppet::Error, "servicenow_change_request#make_request called with invalid request type #{type}"
        end
        request.basic_auth(username, password)
        request['Accept'] = 'application/json'
        response = connection.request(request)
      rescue SocketError => e
        raise Puppet::Error, "Could not connect to the ServiceNow endpoint at #{uri.host}: #{e.inspect}", e.backtrace
      end

      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        return response
      when Net::HTTPInternalServerError
        if attempts < max_attempts # rubocop:disable Style/GuardClause
          Puppet.debug("Received #{response} error from #{uri.host}, attempting to retry. (Attempt #{attempts} of #{max_attempts})")
          Kernel.sleep(3)
        else
          raise Puppet::Error, "Received #{attempts} server error responses from the ServiceNow endpoint at #{uri.host}: #{response.code} #{response.body}"
        end
      else
        return response
      end
    end
  end
end
