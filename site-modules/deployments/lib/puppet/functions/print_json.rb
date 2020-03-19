require 'json'
Puppet::Functions.create_function(:print_json) do
  def print_json(data)
    puts JSON.pretty_generate(data)
  end
end
