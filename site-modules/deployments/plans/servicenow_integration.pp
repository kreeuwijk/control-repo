plan deployments::servicenow_integration(
  String $cd4pe_user,
  String $cd4pe_passwd,
){
  # Read relevant CD4PE environment variables
  $repo_type = system::env('REPO_TYPE')
  $commit_sha = system::env('COMMIT')

  # Hardcode control repo name, as this can't be read from the env vars yet
  $repo_name = 'control-repo'

  # Find out which stage is currently running
  $stage_num = deployments::get_running_stage()

  # Get a cookie for function calls that need it
  $cookie_hash = cd4pe_deployments::get_cookie($cd4pe_user, $cd4pe_passwd)
  $cookie = deployments::eval_result($cookie_hash)

  # Find the pipeline ID for the commit SHA
  $pipeline_id_hash = cd4pe_deployments::search_pipeline($repo_name, $commit_sha, $cookie)
  $pipeline_id = deployments::eval_result($pipeline_id_hash)

  # Loop until items in pipeline stage are done
  ctrl::do_until('limit'=>10) || {
    # Wait 15 seconds for each loop
    ctrl::sleep(15)
    # Get the current pipeline stage status
    $pipeline_hash = cd4pe_deployments::get_pipeline($repo_type, $repo_name, $pipeline_id, $cookie)
    $pipeline = deployments::eval_result($pipeline_hash)
    $pipeline_stage = $pipeline['stages'].filter |$stage| { $stage['stageNum'] == $stage_num }
    # Check if items in the pipeline stage are done
    deployments::pipeline_stage_done($pipeline_stage)
  }
  #$report = deployments::report_pipeline_stage($pipeline, $stage_num)

}

#$deploysdir = module_directory('deployments')  # => /disk/2813153411337507734/control-repo/site-modules/deployments
#file::write('/root/testoutput.txt', "${deploysdir}")
#ctrl::sleep(120)
