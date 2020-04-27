require 'net/http'
require 'uri'
require 'json'

Puppet::Functions.create_function(:'deployments::servicenow_devops_change_request') do
  dispatch :servicenow_devops_change_request do
    required_param 'String', :endpoint
    required_param 'Hash', :report
    required_param 'String', :current_stage
  end

  def servicenow_devops_change_request(endpoint, report, current_stage)
    changereq = {}
    changereq['commitSHA']       = report['scm']['commit']
    changereq['deploymentId']    = report['build']['number']
    changereq['pipelineId']      = report['build']['pipeline']
    changereq['workspace']       = report['build']['owner']
    changereq['repoName']        = report['build']['repo_name']
    changereq['repoType']        = report['build']['repo_type']
    changereq['promoteToStage']  = current_stage.to_i + 1
    changereq['scm_branch']      = report['scm']['branch']
    bln_ia_safe_verdict = true
    report['notes'].each do |ia|
      unless ia['IA_verdict'] == 'safe'
        bln_ia_safe_verdict = false
      end
    end
    changereq['impact_analysis'] = bln_ia_safe_verdict ? 'safe' : 'unsafe'
    make_request(endpoint, changereq)
  end

  def make_request(endpoint, payload)
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
        Puppet.debug("servicenow_devops_change_request: posting to #{endpoint}")
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
