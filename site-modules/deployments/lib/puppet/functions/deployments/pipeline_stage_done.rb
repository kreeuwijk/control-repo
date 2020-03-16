Puppet::Functions.create_function(:'deployments::pipeline_stage_done') do
  dispatch :pipeline_stage_done do
    required_param 'Hash', :pipeline
  end

  def pipeline_stage_done(pipeline)
    
  end
end