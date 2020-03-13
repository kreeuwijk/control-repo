plan deployments::testing(
  String $cd4pe_user,
  String $cd4pe_passwd,
){
  # Read control repo type from CD4PE environment variable
  $repo_type = system::env('REPO_TYPE')
  # Hardcode control repo name, as this can't be read from the env vars yet
  $repo_name = 'control-repo'

  # Get a cookie for function calls that need it
  $cookie = cd4pe_deployments::get_cookie($cd4pe_user, $cd4pe_passwd)
  $events = cd4pe_deployments::list_trigger_events($repo_name, $cookie['result'])

  $deploysdir = module_directory('deployments')  # => /disk/2813153411337507734/control-repo/site-modules/deployments
  file::write('/root/testoutput.txt', "${deploysdir}")
  ctrl::sleep(120)

}
