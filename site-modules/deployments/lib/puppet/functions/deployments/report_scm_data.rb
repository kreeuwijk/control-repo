Puppet::Functions.create_function(:'deployments::report_scm_data') do
  dispatch :report_scm_data do
    required_param 'Hash', :pipeline
  end

  def report_scm_data(pipeline)
    report = {}
    report['scm'] = {}
    report['scm']['url'] = pipeline['buildStage']['imageEvent']['repoUrl']
    report['scm']['branch'] = pipeline['buildStage']['imageEvent']['branch']
    report['scm']['commit'] = pipeline['buildStage']['imageEvent']['commitId']
    report['scm']['changes'] = []
    report['scm']['culprits'] = []
    report
  end
end
