plan deployments::testing(
  String $cd4pe_user,
  Sensitive $cd4pe_passwd,
){
  $repo_type = system::env('REPO_TYPE')
  $repo_name = 'control-repo'
  $deploysdir = module_directory('deployments')  # => /disk/2813153411337507734/control-repo/site-modules/deployments
  #ctrl::sleep(180)
  $cookie = cd4pe_deployments::get_cookie($cd4pe_user, $cd4pe_pwd.unwrap)
  $events = cd4pe_deployments::list_trigger_events($repo_name, $cookie)
  file::write('/root/testoutput.txt', "${events}")

}
