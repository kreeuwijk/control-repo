plan deployments::servicenow_integration(
  String $cd4pe_user,
  String $cd4pe_passwd,
  Integer $max_changes_per_node = 10
){
  # Read relevant CD4PE environment variables
  $repo_type = system::env('REPO_TYPE')
  $commit_sha = system::env('COMMIT')

  # Hardcode control repo name, as this can't be read from the env vars yet
  $repo_name = 'control-repo'

  # Find out which stage is currently running
  $stage_num = deployments::get_running_stage()

  # Get a cookie for function calls that need it
  $cookie_result = cd4pe_deployments::get_cookie($cd4pe_user, $cd4pe_passwd)
  $cookie = deployments::eval_result($cookie_result)

  # Find the pipeline ID for the commit SHA
  $pipeline_search_result = cd4pe_deployments::search_pipeline($repo_name, $commit_sha, $cookie)
  $pipeline_search_hash = deployments::eval_result($pipeline_search_result)
  $pipeline_id = $pipeline_search_hash['id']

  # Loop until items in pipeline stage are done
  $loop_result = ctrl::do_until('limit'=>20) || {
    # Wait 15 seconds for each loop
    ctrl::sleep(15)
    # Get the current pipeline stage status (temporary variables that don't exist outside this loop)
    $pipeline_result = cd4pe_deployments::get_pipeline($repo_type, $repo_name, $pipeline_id, $cookie)
    $pipeline = deployments::eval_result($pipeline_result)
    $pipeline_stage = $pipeline['stages'].filter |$stage| { $stage['stageNum'] == $stage_num }
    # Check if items in the pipeline stage are done
    deployments::pipeline_stage_done($pipeline_stage)
  }
  unless $loop_result {
    fail_plan('Timeout waiting for pipeline stage to finish!', 2)
  }
  # Generate the final variables
  $pipeline_result = cd4pe_deployments::get_pipeline($repo_type, $repo_name, $pipeline_id, $cookie)
  $pipeline = deployments::eval_result($pipeline_result)
  $pipeline_stage = $pipeline['stages'].filter |$stage| { $stage['stageNum'] == $stage_num }

  # Gather pipeline stage reporting
  $scm_data = deployments::report_scm_data($pipeline)
  $stage_report = deployments::report_pipeline_stage($pipeline_stage, $pipeline_search_hash)

  # See if the stage contains an Impact Analysis
  $ia_events = $stage_report['build']['events'].filter |$event| { $event['eventType'] == 'IA' }
  if $ia_events.length > 0 {
    # Get the Impact Analysis report
    $impact_analysis_id = $ia_events[0]['eventNumber']
    $impact_analysis_result = cd4pe_deployments::get_impact_analysis($impact_analysis_id, $cookie)
    $impact_analysis = deployments::eval_result($impact_analysis_result)
    $ia_report = deployments::report_impact_analysis($impact_analysis)

    $ia_envs_report = $ia_report['results'].map |$ia_env_report| {
      $impacted_nodes_result = cd4pe_deployments::search_impacted_nodes($ia_env_report['IA_resultId'], $cookie)
      $impacted_nodes = deployments::eval_result($impacted_nodes_result)
      deployments::report_impacted_nodes($ia_env_report, $impacted_nodes, $max_changes_per_node)
    }
  }
  $report = $stage_report + $scm_data + $ia_envs_report
  print_json($report)


}

#$deploysdir = module_directory('deployments')  # => /disk/2813153411337507734/control-repo/site-modules/deployments
#file::write('/root/testoutput.txt', "${deploysdir}")
#ctrl::sleep(120)