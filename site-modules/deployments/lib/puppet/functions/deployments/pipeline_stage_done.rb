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
    when 'q' then 'QUEUED'
    else
      "Unknown status: #{job_status}"
    end
  end

  def pipeline_stage_done(pipeline_stage)
    bln_done = true
    pipeline_stage[0]['destinations'].each do |item|
      if item.key?('vmJobEvent')
        field_to_check = jobstatus(item['vmJobEvent']['jobStatus'])
      elsif item.key?('deploymentAppEvent')
        field_to_check = if item['deploymentAppEvent']['deploymentPlanName'] == 'deployments::servicenow_integration'
                           'SELF'
                         else
                           item['deploymentAppEvent']['deploymentState']
                         end
      elsif item.key?('peImpactAnalysisEvent')
        field_to_check = item['peImpactAnalysisEvent']['state']
      end
      case field_to_check
      when 'RUNNING', 'QUEUED' then bln_done = false
      end
    end
    bln_done
  end
end
