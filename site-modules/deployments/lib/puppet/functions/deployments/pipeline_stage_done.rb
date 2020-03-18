Puppet::Functions.create_function(:'deployments::pipeline_stage_done') do
  dispatch :pipeline_stage_done do
    required_param 'Tuple', :pipeline_stage
  end

  def jobstatus(job_status)
    case job_status
    when 'f' then 'FAILURE'
    when 's' then 'SUCCESS'
    when 'r' then 'RUNNING'
    when 'c' then 'CANCELED'
    when 'w' then 'QUEUED'
    else
      "Unknown status: #{job_status}"
    end
  end

  def pipeline_stage_done(pipeline_stage)
    bln_done = true
    pipeline_stage[0]['destinations'].each do |event|
      if event.key?('vmJobEvent')
        field_to_check = jobstatus(event['vmJobEvent']['jobStatus'])
      elsif event.key?('deploymentAppEvent')
        field_to_check = if event['deploymentAppEvent']['deploymentPlanName'] == 'deployments::servicenow_integration'
                           'SELF'
                         else
                           event['deploymentAppEvent']['deploymentState']
                         end
      elsif event.key?('peImpactAnalysisEvent')
        field_to_check = event['peImpactAnalysisEvent']['state']
      end
      case field_to_check
      when 'RUNNING', 'QUEUED' then bln_done = false
      end
    end
    bln_done
  end
end
