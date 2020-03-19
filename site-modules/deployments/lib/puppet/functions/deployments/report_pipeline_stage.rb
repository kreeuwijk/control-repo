# frozen_string_literal: true

Puppet::Functions.create_function(:'deployments::report_pipeline_stage') do
  dispatch :report_pipeline_stage do
    required_param 'Tuple', :pipeline_stage
    required_param 'Hash', :pipeline_search_hash
  end

  def add2log(content)
    print(content + "\n")
    @report['log'] = if @report['log'] == ''
                       content
                     else
                       @report['log'] + "\n" + content
                     end
  end

  def jobstatus(job_status)
    case job_status
    when 'f' then 'FAILURE'
    when 's' then 'SUCCESS'
    when 'r' then 'RUNNING'
    when 'c' then 'CANCELED'
    when 'q' then 'QUEUED'
    else
      "Unknown status: #{job_status}"
    end
  end

  def report_pipeline_stage(pipeline_stage, pipeline_search_hash)
    @report = {}
    @report['name'] = 'cd4pe-pipeline'
    @report['display_name'] = 'cd4pe-pipeline'
    @report['build'] = {}
    @report['build']['events'] = []
    @report['notes'] = []
    @report['artifacts'] = {}
    @report['log'] = ''
    @report['build']['full_url'] = ENV['WEB_UI_ENDPOINT'] + '/' + ENV['DEPLOYMENT_OWNER'] + '/repositories/' +
                                   pipeline_search_hash['cd4pe_repoName'] + '?pipelineId=' + pipeline_search_hash['id'] +
                                   '&eventId=' + pipeline_search_hash['eventId'].to_s
    @report['build']['number'] = pipeline_search_hash['eventId']
    @report['build']['phase'] = pipeline_stage[0]['stageName']
    @report['build']['queue_id'] = pipeline_stage[0]['stageNum'].to_i
    @report['build']['url'] = '/' + ENV['DEPLOYMENT_OWNER'] + '/repositories/' + pipeline_search_hash['cd4pe_repoName'] +
                              '?pipelineId=' + pipeline_search_hash['id'] + '&eventId=' + pipeline_search_hash['eventId'].to_s
    @report['url'] = ENV['DEPLOYMENT_OWNER'] + '/repositories/' + pipeline_search_hash['cd4pe_repoName'] +
                     '?pipelineId=' + pipeline_search_hash['id']
    add2log('Pipeline #: ' + pipeline_search_hash['eventId'].to_s)
    add2log(' Stage ' + pipeline_stage[0]['stageNum'].to_s + ': ' + pipeline_stage[0]['stageName'].to_s)
    add2log('  Number of events in stage: ' + (pipeline_stage[0]['destinations'].count - 1).to_s)
    bln_stage_success = true
    pipeline_stage[0]['destinations'].each do |event|
      eventinfo = {}
      if event.key?('vmJobEvent')
        eventinfo['eventName'] = event['vmJobEvent']['jobName']
        eventinfo['eventType'] = 'JOB'
        eventinfo['eventNumber'] = event['vmJobEvent']['vmJobInstanceId']
        eventinfo['eventTime'] = event['vmJobEvent']['eventTime']
        eventinfo['eventResult'] = jobstatus(event['vmJobEvent']['jobStatus'])
        begin
          eventinfo['startTime'] = event['vmJobEvent'].fetch('jobStartTime', event['vmJobEvent']['jobEndTime'])
        rescue
          eventinfo['startTime'] = 0
        end
        begin
          eventinfo['endTime'] = event['vmJobEvent']['jobEndTime']
        rescue
          eventinfo['endTime'] = 0
        end
        eventinfo['executionTime'] = (eventinfo['endTime'] - eventinfo['startTime']) / 1000
        add2log('   Event name: ' + eventinfo['eventName'])
        add2log('    Event status: ' + eventinfo['eventResult'])
        if eventinfo['eventResult'] != 'SUCCESS'
          bln_stage_success = false
        end
      elsif event.key?('deploymentAppEvent')
        next unless event['deploymentAppEvent']['deploymentPlanName'] != 'deployments::servicenow_integration'

        eventinfo['eventName'] = event['deploymentAppEvent']['deploymentPlanName'] + ' to ' + event['deploymentAppEvent']['targetBranch']
        eventinfo['eventType'] = 'DEPLOY'
        eventinfo['eventNumber'] = event['deploymentAppEvent']['deploymentId']
        eventinfo['eventTime'] = event['deploymentAppEvent']['eventTime']
        eventinfo['eventResult'] = event['deploymentAppEvent']['deploymentState']
        eventinfo['startTime'] = if event['deploymentAppEvent']['deploymentStartTime'].zero?
                                   event['deploymentEndTime']
                                 else
                                   event['deploymentAppEvent']['deploymentStartTime']
                                 end
        eventinfo['endTime'] = event['deploymentAppEvent']['deploymentEndTime']
        eventinfo['executionTime'] = (eventinfo['endTime'] - eventinfo['startTime']) / 1000
        add2log('   Deployment name: ' + eventinfo['eventName'])
        add2log('    Deployment status: ' + eventinfo['eventResult'])
        if eventinfo['eventResult'] != 'DONE'
          bln_stage_success = false
        end
      elsif event.key?('peImpactAnalysisEvent')
        eventinfo['eventName'] = 'Impact Analysis'
        eventinfo['eventType'] = 'IA'
        eventinfo['eventNumber'] = event['peImpactAnalysisEvent']['impactAnalysisId']
        eventinfo['eventTime'] = event['peImpactAnalysisEvent']['eventTime']
        eventinfo['eventResult'] = event['peImpactAnalysisEvent']['state']
        eventinfo['startTime'] = event['peImpactAnalysisEvent'].fetch('startTime', event['peImpactAnalysisEvent']['endTime'])
        eventinfo['endTime'] = event['peImpactAnalysisEvent']['endTime']
        eventinfo['executionTime'] = (eventinfo['endTime'] - eventinfo['startTime']) / 1000
        add2log('   ' + eventinfo['eventName'])
        add2log('    Impact Analysis status: ' + eventinfo['eventResult'])
        if eventinfo['eventResult'] != 'DONE'
          bln_stage_success = false
        end
      else
        eventinfo['eventName'] = 'Unknown event'
        eventinfo['eventType'] = 'UNKNOWN'
        eventinfo['eventNumber'] = 0
        eventinfo['eventTime'] = 0
        eventinfo['eventResult'] = 'UNKNOWN'
        eventinfo['startTime'] = 0
        eventinfo['endTime'] = 0
        eventinfo['executionTime'] = 0
        add2log('   Event name: ' + eventinfo['eventName'])
        add2log('    Event status: ' + eventinfo['eventResult'])
      end
      @report['build']['events'].append(eventinfo)
    end

    first_event = @report['build']['events'][0]
    last_event = @report['build']['events'][-1]
    @report['build']['timestamp'] = first_event['eventTime']
    @report['build']['startTime'] = first_event['startTime']
    @report['build']['endTime'] = last_event['endTime']
    @report['build']['executionTime'] = (last_event['endTime'] - first_event['startTime']) / 1000
    if bln_stage_success == true
      add2log(' Stage succeeded')
      @report['build']['status'] = 'SUCCESS'
    else
      add2log(' Stage failed')
      @report['build']['status'] = 'FAILURE'
    end
    @report
  end
end
