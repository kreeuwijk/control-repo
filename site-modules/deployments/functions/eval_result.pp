function deployments::eval_result(Hash $result_hash){
  if $result_hash['error'] =~ NotUndef {
    fail_plan($result_hash['error']['message'], $result_hash['error']['code'])
  }
  $result_hash['result']
}
