Puppet::Functions.create_function(:'deployments::get_running_stage') do
  def get_running_stage # rubocop:disable Naming/AccessorMethodName
    ENV.each do |env_var|
      if env_var[0].start_with?('CD4PE_STAGE_') && env_var[1] == 'RUNNING'
        stage_number = env_var[0].match(%r{^CD4PE_STAGE_(.+?)_.+$})
        return stage_number
      end
    end
  end
end
