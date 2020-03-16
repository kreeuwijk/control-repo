Puppet::Functions.create_function(:'deployments::get_pipeline_stage') do
  dispatch :get_pipeline_stage do
    required_param 'Hash', :pipeline
    required_param 'Integer', :stage_num
  end

  def get_pipeline_stage(pipeline, stage_num)
    pipeline['stages'].each do |stage|
      if stage['stageNum'] == stage_num
        return stage
      end
    end
  end
end
