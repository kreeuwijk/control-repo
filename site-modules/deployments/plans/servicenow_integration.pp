plan deployments::servicenow_integration(
  String $snow_endpoint,
  Optional[Integer] $max_changes_per_node = 10,
  Optional[Integer] $report_stage = undef,
  Optional[Boolean] $snow_change_request = false,
  Optional[String] $snow_changereq_endpoint = undef

){
  # Read relevant CD4PE environment variables
  $repo_type         = system::env('REPO_TYPE')
  $commit_sha        = system::env('COMMIT')
  $control_repo_name = system::env('CONTROL_REPO_NAME')
  $module_name       = system::env('MODULE_NAME')

  $repo_name = $repo_type ? {
    'CONTROL_REPO' => $control_repo_name,
    'MODULE' => $module_name
  }

  # Find out which stage we should report on first
  if $report_stage == undef {
    $stage_num = deployments::get_running_stage()
  } else {
    $stage_num = "${report_stage}" # lint:ignore:only_variable_string
  }

  # Find the pipeline ID for the commit SHA
  $pipeline_id_result = cd4pe_deployments::search_pipeline($repo_name, $commit_sha)
  $pipeline_id = cd4pe_deployments::evaluate_result($pipeline_id_result)

  # Loop until items in the pipeline stage are done
  $loop_result = ctrl::do_until('limit'=>240) || {
    # Wait 15 seconds for each loop
    ctrl::sleep(15)
    # Get the current pipeline stage status (temporary variables that don't exist outside this loop)
    $pipeline_result = cd4pe_deployments::get_pipeline_trigger_event($repo_name, $pipeline_id, $commit_sha)
    $pipeline = cd4pe_deployments::evaluate_result($pipeline_result)
    # Check if items in the pipeline stage are done
    deployments::pipeline_stage_done($pipeline['eventsByStage'][$stage_num])
  }
  unless $loop_result {
    fail_plan('Timeout waiting for pipeline stage to finish!', 'timeout_error')
  }
  # Now that the relevant jobs in the pipeline stage have completed, generate the final pipeline variables
  $pipeline_result = cd4pe_deployments::get_pipeline_trigger_event($repo_name, $pipeline_id, $commit_sha)
  $pipeline = cd4pe_deployments::evaluate_result($pipeline_result)

  # Gather pipeline stage reporting
  $scm_data = deployments::report_scm_data($pipeline)
  $stage_report = deployments::report_pipeline_stage($pipeline, $stage_num, $repo_name)

  # See if the stage contains an Impact Analysis
  $ia_events = $stage_report['build']['events'].filter |$event| { $event['eventType'] == 'IA' }
  if $ia_events.length > 0 {
    # Get the Impact Analysis information
    $impact_analysis_id = $ia_events[0]['eventNumber']
    $impact_analysis_result = cd4pe_deployments::get_impact_analysis($impact_analysis_id)
    $impact_analysis = cd4pe_deployments::evaluate_result($impact_analysis_result)
    $ia_report = deployments::report_impact_analysis($impact_analysis)

    # Generate the detailed Impact Analysis report
    $ia_envs_report = $ia_report['results'].map |$ia_env_report| {
      $impacted_nodes_result = cd4pe_deployments::search_impacted_nodes($ia_env_report['IA_resultId'])
      $impacted_nodes = cd4pe_deployments::evaluate_result($impacted_nodes_result)
      deployments::report_impacted_nodes($ia_env_report, $impacted_nodes, $max_changes_per_node)
    }
  } else {
    $ia_envs_report = Tuple({})
  }

  # Combine all reports into a single hash
  $report = deployments::combine_reports($stage_report, $scm_data, $ia_envs_report)

  ## Interact with ServiceNow
  # Report analyzed stage result to ServiceNow DevOps
  deployments::servicenow_devops_webhook($snow_endpoint, $report)
  if $snow_change_request {
    if $snow_changereq_endpoint == undef {
      fail_plan('No endpoint specified for ServiceNow Change Requests!', 'no_endpoint_error')
    }
    # Trigger Change Request workflow in ServiceNow DevOps
    $actual_current_stage = deployments::get_running_stage()
    deployments::servicenow_devops_change_request($snow_changereq_endpoint, $report, $actual_current_stage)
  }
}
