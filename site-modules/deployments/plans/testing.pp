plan deployments::testing(
  Optional[Integer] $max_node_failure,
  Optional[Boolean] $noop = false,
){
  $repo_type = system::env('REPO_TYPE')
  $repo_name = 'control-repo'
  $events = cd4pe_deployments::list_trigger_events($repo_name)
  file::write('/root/testoutput.txt', $events)
}
