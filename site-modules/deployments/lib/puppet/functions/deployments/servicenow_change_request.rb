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
    # First, we need to create a new ServiceNow Change Request
    description = "Puppet CD4PE Automated Change Request for promoting commit #{report['scm']['commit']} to stage #{promote_to_stage}"
    short_description = "Puppet CD4PE - promote #{report['scm']['commit'][0, 7]} to stage #{promote_to_stage}"
    request_uri = "#{endpoint}/api/sn_chg_rest/v1/change/normal?category=CD4PE&short_description=#{short_description}&description=#{description}"
    changereq_json = make_request(request_uri, :post, username, password)
    raise Puppet::Error, "Received unexpected response from the ServiceNow endpoint: #{changereq_json.code} #{changereq_json.body}" unless changereq_json.is_a?(Net::HTTPSuccess)

    changereq = JSON.parse(changereq_json.body)
    # Next, we associate the CIs that Impact Analysis flagged into the ticket
    array_of_cis = []
    report['notes'].each do |ia|
      ia['IA_node_reports'].each_key do |node|
        ci_req_uri = "#{endpoint}/api/now/table/cmdb_ci?sysparm_query=name=#{node}"
        ci_json = make_request(ci_req_uri, :get, username, password)
        unless ci_json.is_a?(Net::HTTPOK)
          Puppet.debug("servicenow_change_request: could not find CI #{node} in ServiceNow, skipping setting this as an affected CI...")
          next
        end
        ci = JSON.parse(ci_json.body)
        array_of_cis.push(ci['result'][0]['sys_id'])
      end
    end
    if array_of_cis.count.positive?
      assoc_ci_uri = "#{endpoint}/api/sn_chg_rest/v1/change/#{changereq['result']['sys_id']['value']}/ci"
      payload = { 'cmdb_ci_sys_ids' => array_of_cis.join(','), 'association_type' => 'affected' }
      assoc_ci_response = make_request(assoc_ci_uri, :post, username, password, payload)
      raise Puppet::Error, "Received unexpected response from the ServiceNow endpoint: #{assoc_ci_response.code} #{assoc_ci_response.body}" unless assoc_ci_response.is_a?(Net::HTTPSuccess)
    end
    # Finally, we populate the remaining information into the change request
    closenotes = {}
    closenotes['commitSHA']       = report['scm']['commit']
    closenotes['deploymentId']    = report['build']['number']
    closenotes['pipelineId']      = report['build']['pipeline']
    closenotes['workspace']       = report['build']['owner']
    closenotes['repoName']        = report['build']['repo_name']
    closenotes['repoType']        = report['build']['repo_type']
    closenotes['promoteToStage']  = promote_to_stage
    closenotes['scm_branch']      = report['scm']['branch']
    bln_ia_safe_verdict = true
    report['notes'].each do |ia|
      unless ia['IA_verdict'] == 'safe'
        bln_ia_safe_verdict = false
      end
    end
    closenotes['impact_analysis'] = bln_ia_safe_verdict ? 'safe' : 'unsafe'
    change_req_url = "#{endpoint}/api/sn_chg_rest/v1/change/normal/#{changereq['result']['sys_id']['value']}?state=assess"
    payload = {
      'risk_impact_analysis' => report['log'],
      'assignment_group' => 'Change Management',
      'close_notes' => closenotes.to_json,
    }
    final_response = make_request(change_req_url, :patch, username, password, payload)
    raise Puppet::Error, "Received unexpected response from the ServiceNow endpoint: #{final_response.code} #{final_response.body}" unless final_response.is_a?(Net::HTTPSuccess)
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
          request.body = payload.to_json unless payload.nil?
        when :patch
          request = Net::HTTP::Patch.new(uri.request_uri)
          request.body = payload.to_json unless payload.nil?
        else
          raise Puppet::Error, "servicenow_change_request#make_request called with invalid request type #{type}"
        end
        request.basic_auth(username, password)
        request['Content-Type'] = 'application/json'
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
