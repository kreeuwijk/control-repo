plan deployments::testing(
  Optional[Integer] $max_node_failure,
  Optional[Boolean] $noop = false,
){
  $repo_type = system::env('REPO_TYPE')
  $repo_name = 'control-repo'
  $deploysdir = module_directory('deployments')  # => /disk/2813153411337507734/control-repo/site-modules/deployments
  #run_task('deployments::prereqs', localhost, 'Ensure prereqs are installed...')
  #run_task('deployments::install_modules', 'localhost', 'Install module content...', 'deploydir' => $deploysdir)
  #ctrl::sleep(180)
  $events = cd4pe_deployments::list_trigger_events($repo_name)
  file::write('/root/testoutput.txt', $events)

}
