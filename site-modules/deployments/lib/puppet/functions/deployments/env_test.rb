Puppet::Functions.create_function(:'deployments::env_test') do
  dispatch :env_test do
  end

  def env_test
    ENV['COMMIT']
  end
end
