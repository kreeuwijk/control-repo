Puppet::Functions.create_function(:'deployments::env_test') do
  dispatch :env_test do
  end

  def env_test
    return ENV
  end
end
