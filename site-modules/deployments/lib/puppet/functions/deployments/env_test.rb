Puppet::Functions.create_function(:'deployments::env_test') do
  dispatch :env_test do
  end

  def env_test
    result_hash = {}
    ENV.each do |env_var|
      result_hash = result_hash.merge({ env_var[0] => env_var[1] })
    end
    return result_hash
  end
end
